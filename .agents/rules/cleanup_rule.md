# Auto Clean Debug Screenshots Rule

Whenever capturing temporary screenshots for visual debugging or GUI layout verification (e.g. via `screencapture` or script), always delete the temporary screenshot files (e.g. `rm -f shot_*.png` or `.tempmediaStorage`) immediately after viewing or verifying them, so they never accumulate or waste disk space.
