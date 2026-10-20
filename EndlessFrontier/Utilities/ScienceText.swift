import Foundation

/// arXiv titles and abstracts occasionally contain inline TeX such as
/// `$\text{mm}^\text{2}$`. Native text views do not interpret that markup, so
/// this turns common inline math into readable Unicode while leaving the
/// original metadata untouched for copying/citation.
enum ScienceText {
    static func display(_ raw: String) -> String {
        guard raw.contains("$") || raw.contains("\\(") || raw.contains("\\[") else {
            return raw
        }
        var text = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
        let protectedDollar = "\u{E000}"
        text = text.replacingOccurrences(of: "\\$", with: protectedDollar)
        text = replaceDelimitedMath(text, open: "\\(", close: "\\)")
        text = replaceDelimitedMath(text, open: "\\[", close: "\\]")
        text = replaceDollarMath(text)
        text = text.replacingOccurrences(of: protectedDollar, with: "$")
        return tidy(text)
    }

    private static func replaceDelimitedMath(_ text: String, open: String, close: String) -> String {
        var result = ""
        var searchStart = text.startIndex
        while let openRange = text.range(of: open, range: searchStart..<text.endIndex) {
            guard let closeRange = text.range(of: close, range: openRange.upperBound..<text.endIndex) else {
                result += text[searchStart...]
                return result
            }
            result += text[searchStart..<openRange.lowerBound]
            result += LatexTextParser.render(String(text[openRange.upperBound..<closeRange.lowerBound]))
            searchStart = closeRange.upperBound
        }
        result += text[searchStart...]
        return result
    }

    private static func replaceDollarMath(_ text: String) -> String {
        let chars = Array(text)
        var result = ""
        var index = 0
        while index < chars.count {
            guard chars[index] == "$" else {
                result.append(chars[index])
                index += 1
                continue
            }
            let isDisplay = index + 1 < chars.count && chars[index + 1] == "$"
            let markerLength = isDisplay ? 2 : 1
            var cursor = index + markerLength
            var closing = -1
            while cursor < chars.count {
                if chars[cursor] == "$" {
                    if !isDisplay {
                        closing = cursor
                        break
                    }
                    if cursor + 1 < chars.count, chars[cursor + 1] == "$" {
                        closing = cursor
                        break
                    }
                }
                cursor += 1
            }
            if closing >= 0 {
                let content = String(chars[(index + markerLength)..<closing])
                result += LatexTextParser.render(content)
                index = closing + markerLength
            } else {
                result.append(chars[index])
                index += 1
            }
        }
        return result
    }

    private static func tidy(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: " +([,.;:!?])", with: "$1", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A deliberately small TeX-to-readable-text interpreter. It covers the
/// constructs that actually occur in paper titles and abstracts rather than
/// attempting to typeset arbitrary math.
private struct LatexTextParser {
    private let characters: [Character]
    private var index = 0

    static func render(_ source: String) -> String {
        var parser = LatexTextParser(Array(source))
        return parser.parseSequence(stopAtBrace: false)
    }

    private init(_ characters: [Character]) {
        self.characters = characters
    }

    private mutating func parseSequence(stopAtBrace: Bool) -> String {
        var output = ""
        while index < characters.count {
            let character = characters[index]
            if character == "}" {
                index += 1
                if stopAtBrace { break }
                continue
            }
            if character == "{" {
                index += 1
                output += parseSequence(stopAtBrace: true)
                continue
            }
            if character == "\\" {
                var piece = parseCommand()
                if piece.hasPrefix(" "),
                   let previous = output.last,
                   previous == "(" || previous == "[" || previous == "{" || previous.isWhitespace {
                    piece.removeFirst()
                }
                output += piece
                continue
            }
            if character == "^" || character == "_" {
                index += 1
                let argument = parseArgument()
                output += character == "^" ? superscript(argument) : subscripted(argument)
                continue
            }
            if character == "&" {
                index += 1
                output.append(" ")
                continue
            }
            if character.isWhitespace {
                var lookahead = index
                while lookahead < characters.count, characters[lookahead].isWhitespace {
                    lookahead += 1
                }
                if lookahead < characters.count,
                   characters[lookahead] == "^" || characters[lookahead] == "_" {
                    index = lookahead
                    continue
                }
                if !output.isEmpty, !output.hasSuffix(" ") {
                    output.append(" ")
                }
                index += 1
                continue
            }
            output.append(character)
            index += 1
        }
        return output
    }

    private mutating func parseArgument() -> String {
        skipWhitespace()
        guard index < characters.count else { return "" }
        if characters[index] == "{" {
            index += 1
            return parseSequence(stopAtBrace: true)
        }
        if characters[index] == "\\" {
            return parseCommand()
        }
        let character = characters[index]
        index += 1
        return String(character)
    }

    private mutating func parseCommand() -> String {
        index += 1
        guard index < characters.count else { return "" }
        if characters[index].isLetter {
            var name = ""
            while index < characters.count, characters[index].isLetter {
                name.append(characters[index])
                index += 1
            }
            skipWhitespace()
            return applyCommand(name)
        }
        let escaped = characters[index]
        index += 1
        switch escaped {
        case ",", ";", ":", " ", "\n", "\\":
            return " "
        case "!":
            return ""
        case "%", "&", "#", "_", "{", "}", "$":
            return String(escaped)
        case "|":
            return "‖"
        default:
            return String(escaped)
        }
    }

    private mutating func applyCommand(_ name: String) -> String {
        switch name {
        case "text", "textrm", "textnormal", "textup", "textbf", "textit", "emph",
             "mathrm", "mathbf", "mathit", "mathsf", "mathtt", "mathcal", "mathscr",
             "mathfrak", "operatorname", "mbox", "hbox", "ensuremath":
            return parseArgument()

        case "mathbb":
            return blackboard(parseArgument())

        case "frac", "dfrac", "tfrac":
            let numerator = parseArgument()
            let denominator = parseArgument()
            guard !denominator.isEmpty else { return numerator }
            return "\(numerator)/\(denominator)"

        case "sqrt":
            var root = ""
            skipWhitespace()
            if index < characters.count, characters[index] == "[" {
                index += 1
                var rootText = ""
                while index < characters.count, characters[index] != "]" {
                    if characters[index] == "\\" {
                        rootText += parseCommand()
                    } else {
                        rootText.append(characters[index])
                        index += 1
                    }
                }
                if index < characters.count { index += 1 }
                root = superscript(rootText)
            }
            let radicand = parseArgument()
            let body = radicand.count <= 1 || radicand.allSatisfy({ $0.isLetter || $0.isNumber })
                ? radicand
                : "(\(radicand))"
            return root + "√" + body

        case "overline", "bar":
            return accented(parseArgument(), mark: "\u{0305}")
        case "hat", "widehat":
            return accented(parseArgument(), mark: "\u{0302}")
        case "tilde", "widetilde":
            return accented(parseArgument(), mark: "\u{0303}")
        case "vec":
            return accented(parseArgument(), mark: "\u{20D7}")
        case "dot":
            return accented(parseArgument(), mark: "\u{0307}")
        case "ddot":
            return accented(parseArgument(), mark: "\u{0308}")
        case "acute":
            return accented(parseArgument(), mark: "\u{0301}")
        case "grave":
            return accented(parseArgument(), mark: "\u{0300}")
        case "breve":
            return accented(parseArgument(), mark: "\u{0306}")
        case "check":
            return accented(parseArgument(), mark: "\u{030C}")

        case "left", "right", "big", "Big", "bigg", "Bigg",
             "bigl", "bigr", "Bigl", "Bigr", "biggl", "biggr", "Biggl", "Biggr":
            guard index < characters.count else { return "" }
            if characters[index] == "\\" {
                return parseCommand()
            }
            let delimiter = characters[index]
            index += 1
            return delimiter == "." ? "" : String(delimiter)

        case "color", "textcolor":
            _ = parseArgument()
            return parseArgument()

        case "pmod":
            let argument = parseArgument()
            return " (mod \(argument))"

        case "begin", "end":
            _ = parseArgument()
            return ""

        case "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle",
             "limits", "nolimits", "rm", "bf", "it", "cal", "sf", "tt", "mathstrut":
            return ""

        case "quad", "qquad", "enspace", "thinspace", "medspace", "thickspace":
            return " "

        case "degree", "textdegree":
            return "°"
        case "circ":
            return "°"
        case "prime":
            return "′"
        case "ell":
            return "ℓ"
        case "hbar":
            return "ℏ"

        case "alpha": return "α"
        case "beta": return "β"
        case "gamma": return "γ"
        case "delta": return "δ"
        case "epsilon", "varepsilon": return "ε"
        case "zeta": return "ζ"
        case "eta": return "η"
        case "theta": return "θ"
        case "vartheta": return "ϑ"
        case "iota": return "ι"
        case "kappa": return "κ"
        case "lambda": return "λ"
        case "mu": return "μ"
        case "nu": return "ν"
        case "xi": return "ξ"
        case "omicron": return "ο"
        case "pi": return "π"
        case "varpi": return "ϖ"
        case "rho": return "ρ"
        case "varrho": return "ϱ"
        case "sigma": return "σ"
        case "varsigma": return "ς"
        case "tau": return "τ"
        case "upsilon": return "υ"
        case "phi": return "φ"
        case "varphi": return "ϕ"
        case "chi": return "χ"
        case "psi": return "ψ"
        case "omega": return "ω"
        case "Gamma": return "Γ"
        case "Delta": return "Δ"
        case "Theta": return "Θ"
        case "Lambda": return "Λ"
        case "Xi": return "Ξ"
        case "Pi": return "Π"
        case "Sigma": return "Σ"
        case "Upsilon": return "Υ"
        case "Phi": return "Φ"
        case "Psi": return "Ψ"
        case "Omega": return "Ω"

        case "times": return "×"
        case "cdot": return "·"
        case "pm": return "±"
        case "mp": return "∓"
        case "div": return "÷"
        case "leq", "le": return "≤"
        case "geq", "ge": return "≥"
        case "neq", "ne": return "≠"
        case "approx": return "≈"
        case "sim": return "∼"
        case "simeq": return "≃"
        case "cong": return "≅"
        case "equiv": return "≡"
        case "propto": return "∝"
        case "ll": return "≪"
        case "gg": return "≫"
        case "infty": return "∞"
        case "partial": return "∂"
        case "nabla": return "∇"
        case "sum": return "∑"
        case "prod": return "∏"
        case "int": return "∫"
        case "oint": return "∮"
        case "to", "rightarrow": return "→"
        case "leftarrow": return "←"
        case "leftrightarrow": return "↔"
        case "Rightarrow": return "⇒"
        case "Leftarrow": return "⇐"
        case "Leftrightarrow": return "⇔"
        case "mapsto": return "↦"
        case "in": return "∈"
        case "notin": return "∉"
        case "subset": return "⊂"
        case "subseteq": return "⊆"
        case "supset": return "⊃"
        case "supseteq": return "⊇"
        case "cup": return "∪"
        case "cap": return "∩"
        case "emptyset", "varnothing": return "∅"
        case "forall": return "∀"
        case "exists": return "∃"
        case "neg": return "¬"
        case "land", "wedge": return "∧"
        case "lor", "vee": return "∨"
        case "oplus": return "⊕"
        case "otimes": return "⊗"
        case "odot": return "⊙"
        case "perp": return "⊥"
        case "parallel": return "∥"
        case "angle": return "∠"
        case "triangle": return "△"
        case "star": return "⋆"
        case "ast": return "∗"
        case "dagger": return "†"
        case "ddagger": return "‡"
        case "ldots", "dots": return "…"
        case "cdots": return "⋯"
        case "vdots": return "⋮"
        case "ddots": return "⋱"
        case "lVert", "rVert", "Vert": return "‖"
        case "vert", "lvert", "rvert", "mid": return "|"
        case "langle": return "⟨"
        case "rangle": return "⟩"
        case "lceil": return "⌈"
        case "rceil": return "⌉"
        case "lfloor": return "⌊"
        case "rfloor": return "⌋"
        case "lbrace": return "{"
        case "rbrace": return "}"
        case "backslash": return "\\"

        case "log", "ln", "exp", "sin", "cos", "tan", "cot", "sec", "csc",
             "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh",
             "max", "min", "sup", "inf", "lim", "det", "dim", "ker", "deg",
             "gcd", "Pr", "arg", "hom", "rank", "tr", "diag", "mod", "bmod":
            let next = nextNonSpaceCharacter()
            return " " + name + (next == "(" ? "" : " ")

        default:
            return ""
        }
    }

    private func nextNonSpaceCharacter() -> Character? {
        var cursor = index
        while cursor < characters.count, characters[cursor].isWhitespace {
            cursor += 1
        }
        return cursor < characters.count ? characters[cursor] : nil
    }

    private mutating func skipWhitespace() {
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
    }

    private func accented(_ value: String, mark: String) -> String {
        guard let last = value.last else { return value }
        return String(value.dropLast()) + String(last) + mark
    }

    private func blackboard(_ value: String) -> String {
        let map: [Character: Character] = [
            "R": "ℝ", "N": "ℕ", "Z": "ℤ", "Q": "ℚ", "C": "ℂ",
            "P": "ℙ", "H": "ℍ", "E": "𝔼", "F": "𝔽"
        ]
        return String(value.map { map[$0] ?? $0 })
    }

    private func superscript(_ rawValue: String) -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [Character: Character] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
            "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
            "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ",
            "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ", "j": "ʲ",
            "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ",
            "p": "ᵖ", "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ",
            "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
            "A": "ᴬ", "B": "ᴮ", "D": "ᴰ", "E": "ᴱ", "G": "ᴳ",
            "H": "ᴴ", "I": "ᴵ", "J": "ᴶ", "K": "ᴷ", "L": "ᴸ",
            "M": "ᴹ", "N": "ᴺ", "O": "ᴼ", "P": "ᴾ", "R": "ᴿ",
            "T": "ᵀ", "U": "ᵁ", "V": "ⱽ", "W": "ᵂ",
            "°": "°", "′": "′", "″": "″", "*": "*"
        ]
        guard !value.isEmpty else { return "" }
        let mapped = value.compactMap { map[$0] }
        if mapped.count == value.count {
            return String(mapped)
        }
        return value.count == 1 ? "^\(value)" : "^(\(value))"
    }

    private func subscriptText(_ rawValue: String) -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [Character: Character] = [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
            "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
            "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
            "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
            "v": "ᵥ", "x": "ₓ"
        ]
        guard !value.isEmpty else { return "" }
        let mapped = value.compactMap { map[$0] }
        if mapped.count == value.count {
            return String(mapped)
        }
        return value.count == 1 ? "_\(value)" : "_(\(value))"
    }

    private func subscripted(_ value: String) -> String {
        subscriptText(value)
    }
}
