//
//  EPUBParser.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//

import Foundation
import ZIPFoundation

struct EPUBParser: EbookParser {
    func parse(filePath: String, encoding: String? = nil) async throws -> EbookContent {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ParserError.fileNotFound(filePath)
        }
        let archive: Archive
        do {
            archive = try Archive(url: URL(fileURLWithPath: filePath), accessMode: .read)
        } catch {
            throw ParserError.invalidFile
        }

        let opfPath = try extractOPFPath(from: archive)
        let opfDir = (opfPath as NSString).deletingLastPathComponent

        let opfData = try extractData(from: archive, path: opfPath)
        let (metadata, spine, manifest) = try parseOPF(data: opfData)

        let toc = (try? parseTOC(archive: archive, opfDir: opfDir, manifest: manifest)) ?? []

        let useFallback = determineUseFallback(toc: toc)

        let mode: EPUBToHTMLConverter.ConvertMode = useFallback ? .spineBased : .tocBased
        let converter = EPUBToHTMLConverter(
            archive: archive,
            spine: spine,
            manifest: manifest,
            opfDir: opfDir,
            toc: toc
        )
        let html = try await converter.convert(mode: mode)

        return EbookContent(
            format: .epub,
            filePath: filePath,
            title: metadata["title"],
            author: metadata["author"],
            metadata: metadata,
            chapters: toc,
            htmlContent: html,
            pages: nil,
            useFallbackRenderer: useFallback
        )
    }

    private func extractOPFPath(from archive: Archive) throws -> String {
        guard let entry = archive["META-INF/container.xml"],
              let data = try? archive.extractData(from: entry),
              let xml = try? XMLDocument(data: data)
        else { throw ParserError.invalidStructure("Missing container.xml") }

        let root = xml.rootElement()
        let rootfiles = root?.elements(forName: "rootfiles").first
        let rootfile = rootfiles?.elements(forName: "rootfile").first
        guard let path = rootfile?.attribute(forName: "full-path")?.stringValue else {
            throw ParserError.invalidStructure("Missing rootfile path")
        }

        return path
    }

    private func extractData(from archive: Archive, path: String) throws -> Data {
        guard let entry = archive[path],
              let data = try? archive.extractData(from: entry)
        else { throw ParserError.invalidStructure("Cannot read: \(path)") }
        return data
    }

    private func parseOPF(data: Data) throws -> ([String: String], [String], [String: String]) {
        guard let xml = try? XMLDocument(data: data),
              let root = xml.rootElement()
        else { throw ParserError.invalidStructure("Invalid OPF") }

        var metadata: [String: String] = [:]
        if let metaEl = root.elements(forName: "metadata").first {
            metadata["title"] = metaEl.elements(forName: "dc:title").first?.stringValue
            metadata["author"] = metaEl.elements(forName: "dc:creator").first?.stringValue
        }

        var manifest: [String: String] = [:]
        if let manifestEl = root.elements(forName: "manifest").first {
            for item in manifestEl.elements(forName: "item") {
                if let id = item.attribute(forName: "id")?.stringValue,
                   let href = item.attribute(forName: "href")?.stringValue {
                    manifest[id] = href
                }
            }
        }

        var spine: [String] = []
        if let spineEl = root.elements(forName: "spine").first {
            for itemref in spineEl.elements(forName: "itemref") {
                if let idref = itemref.attribute(forName: "idref")?.stringValue {
                    spine.append(idref)
                }
            }
        }

        return (metadata, spine, manifest)
    }

    private func parseTOC(archive: Archive, opfDir: String, manifest: [String: String]) throws -> [EbookContent.Chapter] {
        if let navEntry = manifest.first(where: { $0.value.hasSuffix("nav.xhtml") }) {
            let navHref = navEntry.value
            let navPath = opfDir.isEmpty ? navHref : "\(opfDir)/\(navHref)"
            if let data = try? extractData(from: archive, path: navPath) {
                return parseNavXHTML(data: data, navPath: navPath)
            }
        }
        if let ncxEntry = manifest.first(where: { $0.value.hasSuffix(".ncx") }) {
            let ncxHref = ncxEntry.value
            let ncxPath = opfDir.isEmpty ? ncxHref : "\(opfDir)/\(ncxHref)"
            if let data = try? extractData(from: archive, path: ncxPath) {
                return parseNCX(data: data, ncxPath: ncxPath)
            }
        }
        return []
    }

    private func parseNavXHTML(data: Data, navPath: String) -> [EbookContent.Chapter] {
        guard let xml = try? XMLDocument(data: data, options: .documentTidyHTML) else { return [] }
        var chapters: [EbookContent.Chapter] = []
        let nodes = (try? xml.nodes(forXPath: "//nav//a")) ?? []
        for (i, node) in nodes.enumerated() {
            if let el = node as? XMLElement,
               let href = el.attribute(forName: "href")?.stringValue {
                let resolvedHref = resolveTOCHref(href, basePath: navPath)
                chapters.append(EbookContent.Chapter(
                    title: el.stringValue ?? "Chapter \(i + 1)",
                    anchor: "chapter-\(i)",
                    level: 0,
                    href: resolvedHref
                ))
            }
        }
        return chapters
    }

    private func parseNCX(data: Data, ncxPath: String) -> [EbookContent.Chapter] {
        guard let xml = try? XMLDocument(data: data) else { return [] }
        var chapters: [EbookContent.Chapter] = []
        let navPoints = (try? xml.nodes(forXPath: "//*[local-name()='navPoint']")) ?? []
        for (i, node) in navPoints.enumerated() {
            guard let el = node as? XMLElement else { continue }
            let label = (try? el.nodes(forXPath: ".//*[local-name()='text']"))?.first?.stringValue
                ?? "Chapter \(i + 1)"
            let src = (try? el.nodes(forXPath: ".//*[local-name()='content']/@src"))?.first?.stringValue ?? ""
            let resolvedHref = src.isEmpty ? src : resolveTOCHref(src, basePath: ncxPath)
            chapters.append(EbookContent.Chapter(
                title: label,
                anchor: "chapter-\(i)",
                level: 0,
                href: resolvedHref
            ))
        }
        return chapters
    }

    private func resolveTOCHref(_ href: String, basePath: String) -> String {
        let parts = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let filePart = String(parts.first ?? "")
        let fragment = parts.count > 1 ? String(parts[1]) : nil

        let baseDir = (basePath as NSString).deletingLastPathComponent
        let rawPath: String
        if filePart.isEmpty {
            rawPath = basePath
        } else if filePart.hasPrefix("/") {
            rawPath = String(filePart.dropFirst())
        } else {
            rawPath = baseDir.isEmpty ? filePart : "\(baseDir)/\(filePart)"
        }

        let normalizedPath = normalizeArchivePath(rawPath)
        if let fragment, !fragment.isEmpty {
            return "\(normalizedPath)#\(fragment)"
        }
        return normalizedPath
    }

    private func normalizeArchivePath(_ path: String) -> String {
        var stack: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".":
                continue
            case "..":
                if !stack.isEmpty { _ = stack.removeLast() }
            default:
                stack.append(String(component))
            }
        }
        return stack.joined(separator: "/")
    }

    private func determineUseFallback(toc: [EbookContent.Chapter]) -> Bool {
        if toc.isEmpty { return true }
        if toc.count == 1 {
            return toc[0].title.lowercased().contains("cover")
        }
        return false
    }
}

extension Archive {
    func extractData(from entry: Entry) throws -> Data {
        var data = Data()
        _ = try extract(entry) { data.append($0) }
        return data
    }
}

