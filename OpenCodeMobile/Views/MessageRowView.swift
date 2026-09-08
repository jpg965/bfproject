import SwiftUI

// MARK: - MessageRowView
// 单条消息气泡: 区分用户消息和 AI 消息

struct MessageRowView: View {
    let message: MessageResponse
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // 文本内容
                ForEach(message.parts.filter { $0.isTextType }) { part in
                    MessageContentView(
                        text: part.displayText,
                        isUser: isUser
                    )
                }

                // 工具调用内容
                ForEach(message.parts.filter { !$0.isTextType }) { part in
                    ToolCallView(part: part)
                }

                // 时间和成本
                if let time = message.info.time {
                    HStack(spacing: 8) {
                        if let date = message.info.createdDate {
                            Text(date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let cost = message.info.cost, cost > 0 {
                            Text("$\(String(format: "%.4f", cost))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let tokens = message.info.tokens,
                           let input = tokens.input, let output = tokens.output {
                            Text("\(input)+\(output)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - MessageContentView
// 消息文本内容渲染 (Markdown + 代码高亮)
// MVP 阶段: 简单 Markdown 渲染, 后续可替换为 MarkdownUI + Highlightr

struct MessageContentView: View {
    let text: String
    let isUser: Bool

    var body: some View {
        // 检测是否包含代码块
        if containsCodeBlock {
            VStack(alignment: .leading, spacing: 8) {
                // 渲染 Markdown 文本部分
                ForEach(splitByCodeBlocks(), id: \.self) { segment in
                    if segment.isCode {
                        CodeBlockView(code: segment.content, language: segment.language)
                    } else {
                        SimpleMarkdownView(text: segment.content, isUser: isUser)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isUser ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            SimpleMarkdownView(text: text, isUser: isUser)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 代码块检测与分割

    private var containsCodeBlock: Bool {
        text.contains("```")
    }

    struct CodeSegment: Hashable {
        let content: String
        let isCode: Bool
        let language: String
    }

    private func splitByCodeBlocks() -> [CodeSegment] {
        var segments: [CodeSegment] = []
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [CodeSegment(content: text, isCode: false, language: "")]
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        var lastEnd = 0

        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match else { return }

            // 代码块之前的文本
            if match.range.location > lastEnd {
                let before = nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(CodeSegment(content: before, isCode: false, language: ""))
                }
            }

            // 代码块内容
            let langGroup = match.numberOfRanges > 1 ? nsText.substring(with: match.range(at: 1)) : ""
            let codeGroup = match.numberOfRanges > 2 ? nsText.substring(with: match.range(at: 2)) : ""
            segments.append(CodeSegment(
                content: codeGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                isCode: true,
                language: langGroup
            ))

            lastEnd = match.range.location + match.range.length
        }

        // 最后一段文本
        if lastEnd < nsText.length {
            let after = nsText.substring(with: NSRange(location: lastEnd, length: nsText.length - lastEnd))
            if !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(CodeSegment(content: after, isCode: false, language: ""))
            }
        }

        return segments.isEmpty ? [CodeSegment(content: text, isCode: false, language: "")] : segments
    }
}

// MARK: - SimpleMarkdownView
// 简易 Markdown 渲染 (MVP 版本)
// 后续替换为 MarkdownUI 或 SiriusMarkdown 库

struct SimpleMarkdownView: View {
    let text: String
    let isUser: Bool

    var body: some View {
        // MVP: 直接用 Text + AttributedString 渲染基础 Markdown
        // iOS 15+ 支持 AttributedString 的 Markdown 解析
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(.body)
                .foregroundStyle(isUser ? .primary : .primary)
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}

// MARK: - CodeBlockView
// 代码块渲染
// 后续替换为 Highlightr (highlight.js 的 Swift 封装) 做语法高亮

struct CodeBlockView: View {
    let code: String
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 语言标签
            if !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
            }

            // 代码内容
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - ToolCallView
// 工具调用显示

struct ToolCallView: View {
    let part: MessagePart

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: part.type == .tool ? "wrench.fill" : "checkmark.circle.fill")
                    .font(.caption)
                Text(part.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(part.type == .tool ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
