#!/usr/bin/swift
// mobi_scroll_regression_audit.swift
// MOBI 滚动回归审计 — 静态字段验证
import Foundation

func palmDocDecompress(_ data: Data) -> String {
    var out = [UInt8]()
    out.reserveCapacity(data.count * 3)
    var i = 0
    while i < data.count {
        let c = Int(data[i]); i += 1
        if c == 0 { out.append(0) }
        else if c <= 8 { for _ in 0..<c { if i < data.count { out.append(data[i]); i += 1 } } }
        else if c <= 0x7F { out.append(UInt8(c)) }
        else if c <= 0xBF {
            guard i < data.count else { break }
            let next = Int(data[i]); i += 1
            let dist = ((c & 0x3F) << 3) | (next >> 5)
            let len  = (next & 0x07) + 3
            if dist > 0 {
                let s = out.count - dist
                for j in 0..<len { let x=s+j; if x>=0,x<out.count { out.append(out[x]) } }
            }
        } else { out.append(0x20); out.append(UInt8(c ^ 0x80)) }
    }
    return String(bytes: out, encoding: .utf8) ?? String(bytes: out, encoding: .isoLatin1) ?? ""
}

struct PDBRecord { let offset: Int; let length: Int }
struct PDBHeader { let name: String; let records: [PDBRecord] }

func parsePDB(_ bytes: Data) -> PDBHeader {
    let nb = bytes[0..<min(32,bytes.count)].prefix(while:{$0 != 0})
    let name = String(bytes:nb,encoding:.ascii) ?? ""
    guard bytes.count >= 78 else { return PDBHeader(name:name,records:[]) }
    let rc = Int(bytes[76])<<8|Int(bytes[77])
    var records=[PDBRecord]()
    for i in 0..<rc {
        let b=78+i*8; guard b+4<=bytes.count else { break }
        let off=Int(bytes[b])<<24|Int(bytes[b+1])<<16|Int(bytes[b+2])<<8|Int(bytes[b+3])
        let nb2=b+8
        let noff:Int = (i+1<rc && nb2+4<=bytes.count) ?
            Int(bytes[nb2])<<24|Int(bytes[nb2+1])<<16|Int(bytes[nb2+2])<<8|Int(bytes[nb2+3]) : bytes.count
        records.append(PDBRecord(offset:off,length:max(0,noff-off)))
    }
    return PDBHeader(name:name,records:records)
}

let CONTRACTS = [
    "function updateTheme(","function updateFontSize(",
    "function updateLineHeight(","function updateFontFamily(",
    "window.webkit.messageHandlers.onScroll.postMessage",
    "window.webkit.messageHandlers.onLoad.postMessage"
]

func cssOverflowY(_ html:String, sel:String) -> String {
    var sr = html.startIndex..<html.endIndex
    while let so=html.range(of:"<style",options:.caseInsensitive,range:sr),
          let sc=html.range(of:"</style>",options:.caseInsensitive,range:so.upperBound..<html.endIndex) {
        let css = String(html[so.lowerBound..<sc.upperBound])
        let lines = css.components(separatedBy:"\n")
        var inB=false, depth=0
        for line in lines {
            let t=line.trimmingCharacters(in:.whitespaces)
            if !inB {
                let tags = sel=="html" ? ["html {","html{","html,"] : ["body {","body{",",body {"]
                if tags.contains(where:{t.contains($0)}) {
                    inB=true; depth=t.filter({$0=="{"}).count-t.filter({$0=="}"}).count
                    if t.contains("overflow-y:"),let r=t.range(of:"overflow-y:") {
                        return String(t[r.upperBound...]).replacingOccurrences(of:";",with:"").trimmingCharacters(in:.whitespaces)
                    }
                    if depth<=0 { inB=false }
                }
            } else {
                depth+=t.filter({$0=="{"}).count; depth-=t.filter({$0=="}"}).count
                if t.contains("overflow-y:"),let r=t.range(of:"overflow-y:") {
                    return String(t[r.upperBound...]).replacingOccurrences(of:";",with:"").trimmingCharacters(in:.whitespaces)
                }
                if depth<=0 { inB=false }
            }
        }
        sr=sc.upperBound..<html.endIndex
    }
    return "visible"
}

func buildShell(_ raw:String, title:String) -> String {
    let tr=raw.trimmingCharacters(in:.whitespacesAndNewlines)
    if CONTRACTS.allSatisfy({tr.contains($0)}) { return tr }
    let body:String
    if let bs=tr.range(of:"<body[^>]*>",options:[.regularExpression,.caseInsensitive]),
       let be=tr.range(of:"</body>",options:[.regularExpression,.caseInsensitive,.backwards]),
       bs.upperBound<=be.lowerBound { body=String(tr[bs.upperBound..<be.lowerBound]) }
    else { body=tr }
    return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>\(title)</title>
<style>
:root{--bg-color:#F9F7F1;--text-color:#333333;--font-size:18px;--line-height:1.6;--font-family:-apple-system,'PingFang SC',sans-serif;}
*{margin:0;padding:0;box-sizing:border-box;}
html{scroll-behavior:smooth;height:auto;min-height:100%;overflow-y:auto;}
body{background-color:var(--bg-color);color:var(--text-color);font-size:var(--font-size);line-height:var(--line-height);font-family:var(--font-family);padding:40px;max-width:800px;margin:0 auto;overflow-wrap:anywhere;height:auto;min-height:0;overflow-y:auto;}
img{max-width:100%;height:auto;display:block;margin:20px auto;}
p{margin-bottom:1em;text-indent:2em;}
h1,h2,h3,h4,h5,h6{margin-top:1.5em;margin-bottom:0.5em;font-weight:600;}
</style></head><body>
\(body)
<script>
function scrollToChapter(index){const el=document.getElementById('chapter-'+index);if(el){el.scrollIntoView({behavior:'smooth',block:'start'});return true;}return false;}
function updateTheme(bgColor,textColor){document.documentElement.style.setProperty('--bg-color',bgColor);document.documentElement.style.setProperty('--text-color',textColor);}
function updateFontSize(size){document.documentElement.style.setProperty('--font-size',size+'px');}
function updateLineHeight(h){document.documentElement.style.setProperty('--line-height',h);}
function updateFontFamily(f){document.documentElement.style.setProperty('--font-family',f+",'PingFang SC',sans-serif");}
window.addEventListener('scroll',function(){const st=window.pageYOffset;const sh=document.documentElement.scrollHeight-document.documentElement.clientHeight;const p=sh>0?st/sh:0;window.webkit.messageHandlers.onScroll.postMessage(p);});
window.addEventListener('load',function(){window.webkit.messageHandlers.onLoad.postMessage(null);});
</script></body></html>
"""
}

func parseMOBI(_ path:String) -> (html:String,mode:String,ok:Bool,note:String) {
    guard let data=try? Data(contentsOf:URL(fileURLWithPath:path)) else { return ("","N/A",false,"file_read_error") }
    let pdb=parsePDB(data)
    guard !pdb.records.isEmpty else { return ("","N/A",false,"no_pdb_records") }
    let r0=pdb.records[0]
    guard r0.offset+r0.length<=data.count,r0.length>=14 else { return ("","N/A",false,"record0_invalid") }
    let rec0=data.subdata(in:r0.offset..<(r0.offset+r0.length))
    let comp=Int(rec0[0])<<8|Int(rec0[1])
    let enc=Int(rec0[12])<<8|Int(rec0[13])
    if enc != 0 { return ("","N/A",false,"drm_protected") }
    if comp == 17480 { return ("","N/A",false,"unsupported_huffman") }
    var moff = -1
    for i in 0..<(rec0.count-3) {
        if rec0[i]==0x4D,rec0[i+1]==0x4F,rec0[i+2]==0x42,rec0[i+3]==0x49 { moff=i; break }
    }
    var fc=1,lc=1,fi=Int.max
    if moff>=0,moff+96<=rec0.count {
        fc=Int(rec0[moff+80])<<24|Int(rec0[moff+81])<<16|Int(rec0[moff+82])<<8|Int(rec0[moff+83])
        lc=Int(rec0[moff+84])<<24|Int(rec0[moff+85])<<16|Int(rec0[moff+86])<<8|Int(rec0[moff+87])
        fi=Int(rec0[moff+92])<<24|Int(rec0[moff+93])<<16|Int(rec0[moff+94])<<8|Int(rec0[moff+95])
    } else if rec0.count>=10 { fc=1; lc=Int(rec0[8])<<8|Int(rec0[9]) }
    if fc==0 { fc=1 }
    let heuristic=fc>lc||fc>=pdb.records.count||fc==0xFFFF_FFFF
    let mode=heuristic ? "heuristic" : "standard"
    var html=""
    if heuristic {
        for i in 1..<pdb.records.count {
            if fi != Int.max, i>=fi { continue }
            let rec=pdb.records[i]
            guard rec.offset+rec.length<=data.count,rec.length>=10 else { continue }
            let rd=data.subdata(in:rec.offset..<(rec.offset+rec.length))
            let dec=comp==2 ? palmDocDecompress(rd) : (String(data:rd,encoding:.utf8) ?? String(data:rd,encoding:.isoLatin1) ?? "")
            if dec.contains("<")||dec.contains("&") { html+=dec }
        }
    } else {
        let end=min(lc,pdb.records.count-1)
        if fc<=end {
            for i in fc...end {
                let rec=pdb.records[i]
                guard rec.offset+rec.length<=data.count else { continue }
                let rd=data.subdata(in:rec.offset..<(rec.offset+rec.length))
                html += comp==2 ? palmDocDecompress(rd) : (String(data:rd,encoding:.utf8) ?? String(data:rd,encoding:.isoLatin1) ?? "")
            }
        }
    }
    return (html,mode,!html.isEmpty,html.isEmpty ? "empty_content" : "ok")
}

// MARK: - 主程序
let samples = [
    "/Users/whzp/Desktop/书架/华章经典·金融投资系列典藏版（上）（套装共13册）（有史以来华尔街伟大的投资大师如是说，大师思想全解析） ( etc.) (Z-Library).mobi",
    "/Users/whzp/Desktop/书架/两汉风云（套装共3册） (渤海小吏) (z-library.sk, 1lib.sk, z-lib.sk).mobi",
    "/Users/whzp/Desktop/书架/黄帝内经（精注全译） (崇贤书院) (Z-Library).mobi"
]

struct Result {
    var sample,mode,note: String
    var sizeMB: Double
    var parseOK,hasText,canScroll: Bool
    var htmlOY,bodyOY,scrollH,clientH: String
    var jsFailCount: Int
    var jsFailed: [String]
    var htmlLen: Int
}

var results=[Result]()
print("\n=== MOBI 滚动回归审计 (当前已修复源码) ===")
print("审计时间: \(Date())\n")

for path in samples {
    let name=URL(fileURLWithPath:path).lastPathComponent
    let sizeBytes=(try? FileManager.default.attributesOfItem(atPath:path)[.size] as? Int) ?? 0
    let sizeMB=Double(sizeBytes)/1_048_576.0
    print("──