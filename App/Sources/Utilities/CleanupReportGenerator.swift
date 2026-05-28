// App/Sources/Utilities/CleanupReportGenerator.swift
//
// Generates PDF and CSV cleanup reports from CleanedItemStore history.
// Premium feature — shows what was cleaned, when, sizes, and categories.

import Foundation
import AppKit
import PDFKit

public final class CleanupReportGenerator {

    public enum Format { case pdf, csv }

    // MARK: - Generate & Save

    public static func generate(format: Format) {
        let panel = NSSavePanel()
        panel.title = "Export Cleanup Report"
        panel.nameFieldStringValue = "Pare_Cleanup_Report_\(dateStamp()).\(format == .pdf ? "pdf" : "csv")"
        panel.allowedContentTypes = format == .pdf ? [.pdf] : [.commaSeparatedText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        switch format {
        case .pdf: savePDF(to: url)
        case .csv: saveCSV(to: url)
        }

        // Open in Finder
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    // MARK: - CSV

    private static func saveCSV(to url: URL) {
        let store = CleanedItemStore.shared
        var csv = "File Name,Original Path,Category,Size (bytes),Size (formatted),Date Cleaned,Days Remaining\n"

        for item in store.items {
            let name = item.fileName.replacingOccurrences(of: ",", with: ";")
            let path = item.originalPath.replacingOccurrences(of: ",", with: ";")
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
            let date = fmt.string(from: item.cleanedDate)
            csv += "\(name),\(path),\(item.category),\(item.bytes),\(item.sizeLabel),\(date),\(item.daysLeft)\n"
        }

        // Summary row
        csv += "\n"
        csv += "TOTAL,,\(store.totalCount) items,\(store.totalBytes),\(store.totalSizeLabel),,\n"

        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - PDF

    private static func savePDF(to url: URL) {
        let store = CleanedItemStore.shared
        let licence = LicenceManager.shared
        let pageWidth: CGFloat = 595   // A4
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 50

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        // Page 1 — Header + Summary
        context.beginPDFPage(nil)
        var y = pageHeight - margin

        // Title
        y = drawText("Pare Cleanup Report", at: CGPoint(x: margin, y: y), fontSize: 24, bold: true, context: context)
        y -= 8
        y = drawText(dateLabel(), at: CGPoint(x: margin, y: y), fontSize: 11, color: .gray, context: context)
        y -= 24

        // Summary box
        y = drawText("Summary", at: CGPoint(x: margin, y: y), fontSize: 16, bold: true, context: context)
        y -= 6
        y = drawText("Total items cleaned: \(store.totalCount)", at: CGPoint(x: margin, y: y), fontSize: 11, context: context)
        y -= 4
        y = drawText("Total space reclaimed: \(store.totalSizeLabel)", at: CGPoint(x: margin, y: y), fontSize: 11, context: context)
        y -= 4
        y = drawText("Licence tier: \(licence.tier.rawValue.capitalized)", at: CGPoint(x: margin, y: y), fontSize: 11, context: context)
        y -= 4
        y = drawText("Mac: \(Host.current().localizedName ?? "Unknown")", at: CGPoint(x: margin, y: y), fontSize: 11, context: context)
        y -= 20

        // Category breakdown
        y = drawText("By Category", at: CGPoint(x: margin, y: y), fontSize: 14, bold: true, context: context)
        y -= 6

        let categories = Dictionary(grouping: store.items, by: \.category)
        for (cat, items) in categories.sorted(by: { $0.value.reduce(0) { $0 + $1.bytes } > $1.value.reduce(0) { $0 + $1.bytes } }) {
            let total = items.reduce(Int64(0)) { $0 + $1.bytes }
            let label = "\(cat): \(items.count) items — \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
            y = drawText(label, at: CGPoint(x: margin + 10, y: y), fontSize: 10, context: context)
            y -= 2
        }
        y -= 16

        // Items table header
        y = drawText("Cleaned Items", at: CGPoint(x: margin, y: y), fontSize: 14, bold: true, context: context)
        y -= 8
        y = drawText("File Name                                        Category          Size        Date", at: CGPoint(x: margin, y: y), fontSize: 9, color: .gray, context: context)
        y -= 4

        // Draw line
        context.setStrokeColor(CGColor(gray: 0.8, alpha: 1))
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        context.strokePath()
        y -= 8

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "dd MMM yyyy"

        for item in store.items {
            if y < margin + 40 {
                context.endPDFPage()
                context.beginPDFPage(nil)
                y = pageHeight - margin
            }

            let name = String(item.fileName.prefix(45))
            let cat = String(item.category.prefix(16))
            let size = item.sizeLabel
            let date = dateFmt.string(from: item.cleanedDate)
            let line = "\(name.padding(toLength: 50, withPad: " ", startingAt: 0))\(cat.padding(toLength: 18, withPad: " ", startingAt: 0))\(size.padding(toLength: 12, withPad: " ", startingAt: 0))\(date)"

            y = drawText(line, at: CGPoint(x: margin, y: y), fontSize: 9, context: context)
            y -= 2
        }

        // Footer
        y -= 16
        y = drawText("Generated by Pare v1.0 — getpare.lemonsqueezy.com", at: CGPoint(x: margin, y: y), fontSize: 8, color: .gray, context: context)
        y = drawText("All cleanup operations are local. No data was transmitted.", at: CGPoint(x: margin, y: y - 4), fontSize: 8, color: .gray, context: context)

        context.endPDFPage()
        context.closePDF()

        try? pdfData.write(to: url, options: .atomic)
    }

    // MARK: - Text Drawing

    @discardableResult
    private static func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, bold: Bool = false, color: NSColor = .black, context: CGContext) -> CGFloat {
        let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let bounds = CTLineGetBoundsWithOptions(line, [])

        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: point.x, y: point.y - bounds.height)
        CTLineDraw(line, context)
        context.restoreGState()

        return point.y - bounds.height - 4
    }

    private static func dateStamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private static func dateLabel() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, d MMMM yyyy 'at' HH:mm"
        return fmt.string(from: Date())
    }
}
