import SwiftUI

/// Individual lyric line with opacity-based styling for past/current/future states
struct LyricLineView: View {
    let line: LyricLine
    let state: LyricLineState
    let fontSize: Double

    var body: some View {
        Text(line.text)
            .font(.system(size: fontSize))
            .foregroundColor(.white)
            .opacity(textOpacity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var textOpacity: Double {
        switch state {
        case .past:
            return 0.4   // Darker (past lyrics)
        case .current:
            return 1.0   // Brightest (current line)
        case .future:
            return 0.7   // Medium brightness (upcoming lyrics)
        }
    }
}

/// Visual state for a lyric line
enum LyricLineState: Equatable {
    case past
    case current
    case future
}
