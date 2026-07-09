// Converts the Markdown files in this folder to printable HTML and PDF.
// Uses Windows Script Host plus Microsoft Edge headless printing.

var fso = new ActiveXObject("Scripting.FileSystemObject");
var shell = new ActiveXObject("WScript.Shell");

var scriptPath = WScript.ScriptFullName;
var root = fso.GetParentFolderName(scriptPath);
var htmlDir = fso.BuildPath(root, "html");
var pdfDir = fso.BuildPath(root, "pdf");
var profileDir = fso.BuildPath(root, "edge-profile");
var edge = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";

if (!fso.FileExists(edge)) {
    throw new Error("Microsoft Edge was not found at: " + edge);
}

if (!fso.FolderExists(htmlDir)) {
    fso.CreateFolder(htmlDir);
}
if (!fso.FolderExists(pdfDir)) {
    fso.CreateFolder(pdfDir);
}
if (!fso.FolderExists(profileDir)) {
    fso.CreateFolder(profileDir);
}

function readText(path) {
    var file = fso.OpenTextFile(path, 1, false, -1);
    var text = file.ReadAll();
    file.Close();
    return text;
}

function writeText(path, text) {
    var file = fso.OpenTextFile(path, 2, true, -1);
    file.Write(text);
    file.Close();
}

function htmlEscape(s) {
    return s.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
}

function inlineFormat(s) {
    s = htmlEscape(s);
    s = s.replace(/`([^`]+)`/g, "<code>$1</code>");
    s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    return s;
}

function closeLists(state, out) {
    if (state.ul) {
        out.push("</ul>");
        state.ul = false;
    }
    if (state.ol) {
        out.push("</ol>");
        state.ol = false;
    }
}

function mdToHtml(md, title) {
    var lines = md.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    var out = [];
    var state = { ul: false, ol: false, code: false };
    var codeLines = [];

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var trimmed = line.replace(/^\s+|\s+$/g, "");

        if (trimmed.indexOf("```") === 0) {
            if (!state.code) {
                closeLists(state, out);
                state.code = true;
                codeLines = [];
            } else {
                out.push("<pre><code>" + htmlEscape(codeLines.join("\n")) + "</code></pre>");
                state.code = false;
            }
            continue;
        }

        if (state.code) {
            codeLines.push(line);
            continue;
        }

        if (trimmed === "") {
            closeLists(state, out);
            continue;
        }

        var h = /^(#{1,6})\s+(.*)$/.exec(line);
        if (h) {
            closeLists(state, out);
            var level = h[1].length;
            out.push("<h" + level + ">" + inlineFormat(h[2]) + "</h" + level + ">");
            continue;
        }

        var bullet = /^\s*[-*]\s+(.*)$/.exec(line);
        if (bullet) {
            if (!state.ul) {
                closeLists({ ul: false, ol: state.ol }, out);
                state.ol = false;
                out.push("<ul>");
                state.ul = true;
            }
            out.push("<li>" + inlineFormat(bullet[1]) + "</li>");
            continue;
        }

        var numbered = /^\s*\d+\.\s+(.*)$/.exec(line);
        if (numbered) {
            if (!state.ol) {
                closeLists({ ul: state.ul, ol: false }, out);
                state.ul = false;
                out.push("<ol>");
                state.ol = true;
            }
            out.push("<li>" + inlineFormat(numbered[1]) + "</li>");
            continue;
        }

        closeLists(state, out);
        if (/^>\s?/.test(line)) {
            out.push("<blockquote>" + inlineFormat(line.replace(/^>\s?/, "")) + "</blockquote>");
        } else {
            out.push("<p>" + inlineFormat(line) + "</p>");
        }
    }

    if (state.code) {
        out.push("<pre><code>" + htmlEscape(codeLines.join("\n")) + "</code></pre>");
    }
    closeLists(state, out);

    return "<!doctype html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<title>" +
        htmlEscape(title) + "</title>\n<style>\n" +
        "@page { size: A4; margin: 16mm 15mm; }\n" +
        "body { font-family: Aptos, Calibri, Arial, sans-serif; font-size: 10.5pt; line-height: 1.38; color: #111827; }\n" +
        "h1 { font-size: 22pt; margin: 0 0 12pt; border-bottom: 1px solid #d1d5db; padding-bottom: 6pt; }\n" +
        "h2 { font-size: 15pt; margin: 18pt 0 7pt; page-break-after: avoid; }\n" +
        "h3 { font-size: 12.5pt; margin: 13pt 0 5pt; page-break-after: avoid; }\n" +
        "h4, h5, h6 { font-size: 11pt; margin: 10pt 0 4pt; page-break-after: avoid; }\n" +
        "p { margin: 0 0 7pt; }\n" +
        "ul, ol { margin: 0 0 8pt 18pt; padding: 0; }\n" +
        "li { margin: 2pt 0; }\n" +
        "code { font-family: Consolas, monospace; font-size: 9pt; background: #f3f4f6; padding: 1pt 3pt; border-radius: 3pt; }\n" +
        "pre { background: #f3f4f6; border: 1px solid #e5e7eb; padding: 7pt; overflow-wrap: break-word; white-space: pre-wrap; page-break-inside: avoid; }\n" +
        "pre code { background: transparent; padding: 0; }\n" +
        "blockquote { border-left: 3pt solid #9ca3af; margin: 7pt 0; padding: 2pt 0 2pt 8pt; color: #374151; }\n" +
        "a { color: #1d4ed8; text-decoration: none; }\n" +
        "</style>\n</head>\n<body>\n" + out.join("\n") + "\n</body>\n</html>\n";
}

function fileUri(path) {
    var absolute = fso.GetAbsolutePathName(path).replace(/\\/g, "/");
    return "file:///" + encodeURI(absolute);
}

function baseNameNoExt(path) {
    return fso.GetBaseName(path);
}

var folder = fso.GetFolder(root);
var files = new Enumerator(folder.Files);
var made = [];

for (; !files.atEnd(); files.moveNext()) {
    var file = files.item();
    if (String(fso.GetExtensionName(file.Name)).toLowerCase() !== "md") {
        continue;
    }

    var base = baseNameNoExt(file.Path);
    var htmlPath = fso.BuildPath(htmlDir, base + ".html");
    var pdfPath = fso.BuildPath(pdfDir, base + ".pdf");
    var html = mdToHtml(readText(file.Path), file.Name);
    writeText(htmlPath, html);

    var command = "\"" + edge + "\" --headless=new --disable-gpu --no-first-run --no-default-browser-check " +
        "--user-data-dir=\"" + profileDir + "\" --print-to-pdf=\"" + pdfPath + "\" \"" +
        fileUri(htmlPath) + "\"";
    var code = shell.Run(command, 1, true);
    if (code !== 0) {
        WScript.Echo("Edge returned " + code + " for " + file.Name);
    }
    if (!fso.FileExists(pdfPath) || fso.GetFile(pdfPath).Size === 0) {
        WScript.Echo("PDF was not created for " + file.Name + ": " + pdfPath);
    }
    made.push(pdfPath);
}

WScript.Echo("Created PDFs:");
for (var j = 0; j < made.length; j++) {
    WScript.Echo(made[j]);
}
