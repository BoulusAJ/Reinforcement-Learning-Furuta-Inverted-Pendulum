// Self-contained Markdown-to-PDF fallback for printing notes.
// It writes simple text PDFs directly, avoiding Pandoc/Edge/Python dependencies.

var fso = new ActiveXObject("Scripting.FileSystemObject");
var root = fso.GetParentFolderName(WScript.ScriptFullName);
var pdfDir = fso.BuildPath(root, "pdf");

if (!fso.FolderExists(pdfDir)) {
    fso.CreateFolder(pdfDir);
}

function readUtf8(path) {
    var stream = new ActiveXObject("ADODB.Stream");
    stream.Type = 2;
    stream.Charset = "utf-8";
    stream.Open();
    stream.LoadFromFile(path);
    var text = stream.ReadText();
    stream.Close();
    return text;
}

function writeAscii(path, text) {
    var file = fso.CreateTextFile(path, true, false);
    file.Write(text);
    file.Close();
}

function cleanText(s) {
    s = s.replace(/\t/g, "    ");
    s = s.replace(/\u2018|\u2019/g, "'");
    s = s.replace(/\u201c|\u201d/g, '"');
    s = s.replace(/\u2013|\u2014/g, "-");
    s = s.replace(/\u00b0/g, " deg");
    s = s.replace(/\u03c0/g, "pi");
    s = s.replace(/[^\x20-\x7e]/g, " ");
    return s;
}

function pdfEscape(s) {
    return cleanText(s).replace(/\\/g, "\\\\")
                       .replace(/\(/g, "\\(")
                       .replace(/\)/g, "\\)");
}

function byteLen(s) {
    return s.length;
}

function wrapText(text, maxChars) {
    text = cleanText(text);
    if (text.length <= maxChars) {
        return [text];
    }
    var words = text.split(/\s+/);
    var lines = [];
    var line = "";
    for (var i = 0; i < words.length; i++) {
        var w = words[i];
        if (w.length > maxChars) {
            if (line !== "") {
                lines.push(line);
                line = "";
            }
            while (w.length > maxChars) {
                lines.push(w.substr(0, maxChars));
                w = w.substr(maxChars);
            }
            line = w;
        } else if (line === "") {
            line = w;
        } else if ((line + " " + w).length <= maxChars) {
            line += " " + w;
        } else {
            lines.push(line);
            line = w;
        }
    }
    if (line !== "") {
        lines.push(line);
    }
    return lines;
}

function PdfDoc(title) {
    this.title = title;
    this.pages = [];
    this.current = [];
    this.y = 790;
    this.marginLeft = 48;
    this.marginBottom = 45;
    this.pageWidth = 595;
}

PdfDoc.prototype.newPage = function() {
    if (this.current.length > 0) {
        this.pages.push(this.current);
    }
    this.current = [];
    this.y = 790;
};

PdfDoc.prototype.ensure = function(height) {
    if (this.y - height < this.marginBottom) {
        this.newPage();
    }
};

PdfDoc.prototype.textLine = function(text, size, x, leading) {
    this.ensure(leading);
    this.current.push("BT /F1 " + size + " Tf 1 0 0 1 " + x + " " + this.y + " Tm (" + pdfEscape(text) + ") Tj ET");
    this.y -= leading;
};

PdfDoc.prototype.addBlock = function(text, size, indent, leading, before) {
    if (before) {
        this.y -= before;
    }
    var x = this.marginLeft + indent;
    var maxWidth = this.pageWidth - x - 45;
    var maxChars = Math.max(24, Math.floor(maxWidth / (size * 0.52)));
    var lines = wrapText(text, maxChars);
    for (var i = 0; i < lines.length; i++) {
        this.textLine(lines[i], size, x, leading);
    }
};

PdfDoc.prototype.finish = function() {
    if (this.current.length > 0) {
        this.pages.push(this.current);
    }
    if (this.pages.length === 0) {
        this.pages.push([]);
    }
};

function mdToBlocks(md, title) {
    var doc = new PdfDoc(title);
    var lines = md.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    var inCode = false;
    var blank = false;

    for (var i = 0; i < lines.length; i++) {
        var raw = lines[i];
        var line = raw.replace(/^\s+|\s+$/g, "");

        if (line.indexOf("```") === 0) {
            inCode = !inCode;
            blank = false;
            continue;
        }

        if (line === "") {
            if (!blank) {
                doc.y -= 4;
            }
            blank = true;
            continue;
        }
        blank = false;

        if (inCode) {
            doc.addBlock(raw, 8.5, 14, 11, 0);
            continue;
        }

        var h = /^(#{1,6})\s+(.*)$/.exec(line);
        if (h) {
            var level = h[1].length;
            var size = level === 1 ? 20 : (level === 2 ? 15 : 12);
            var lead = level === 1 ? 25 : (level === 2 ? 19 : 15);
            var before = level === 1 ? 8 : 7;
            doc.addBlock(h[2], size, 0, lead, before);
            continue;
        }

        var bullet = /^\s*[-*]\s+(.*)$/.exec(raw);
        if (bullet) {
            doc.addBlock("- " + bullet[1], 10.5, 14, 13, 0);
            continue;
        }

        var numbered = /^\s*(\d+)\.\s+(.*)$/.exec(raw);
        if (numbered) {
            doc.addBlock(numbered[1] + ". " + numbered[2], 10.5, 14, 13, 0);
            continue;
        }

        var quote = /^>\s?(.*)$/.exec(raw);
        if (quote) {
            doc.addBlock("> " + quote[1], 10.5, 14, 13, 1);
        } else {
            doc.addBlock(raw, 10.5, 0, 13, 0);
        }
    }

    doc.finish();
    return doc;
}

function buildPdf(doc) {
    var objects = [];
    var pageKids = [];

    objects.push("<< /Type /Catalog /Pages 2 0 R >>");
    objects.push(null);
    objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

    for (var i = 0; i < doc.pages.length; i++) {
        var content = doc.pages[i].join("\n") + "\n";
        var contentObjNum = objects.length + 2;
        var pageObjNum = objects.length + 1;
        pageKids.push(pageObjNum + " 0 R");
        objects.push("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents " + contentObjNum + " 0 R >>");
        objects.push("<< /Length " + byteLen(content) + " >>\nstream\n" + content + "endstream");
    }

    objects[1] = "<< /Type /Pages /Kids [" + pageKids.join(" ") + "] /Count " + doc.pages.length + " >>";

    var pdf = "%PDF-1.4\n";
    var offsets = [0];
    for (var j = 0; j < objects.length; j++) {
        offsets.push(byteLen(pdf));
        pdf += (j + 1) + " 0 obj\n" + objects[j] + "\nendobj\n";
    }
    var xref = byteLen(pdf);
    pdf += "xref\n0 " + (objects.length + 1) + "\n";
    pdf += "0000000000 65535 f \n";
    for (var k = 1; k < offsets.length; k++) {
        var off = "0000000000" + offsets[k];
        pdf += off.substr(off.length - 10) + " 00000 n \n";
    }
    pdf += "trailer\n<< /Size " + (objects.length + 1) + " /Root 1 0 R >>\n";
    pdf += "startxref\n" + xref + "\n%%EOF\n";
    return pdf;
}

var folder = fso.GetFolder(root);
var files = new Enumerator(folder.Files);
var made = [];

for (; !files.atEnd(); files.moveNext()) {
    var file = files.item();
    if (String(fso.GetExtensionName(file.Name)).toLowerCase() !== "md") {
        continue;
    }
    var base = fso.GetBaseName(file.Path);
    var md = readUtf8(file.Path);
    var doc = mdToBlocks(md, file.Name);
    var pdf = buildPdf(doc);
    var pdfPath = fso.BuildPath(pdfDir, base + ".pdf");
    writeAscii(pdfPath, pdf);
    made.push(pdfPath);
}

WScript.Echo("Created simple PDFs:");
for (var m = 0; m < made.length; m++) {
    WScript.Echo(made[m]);
}
