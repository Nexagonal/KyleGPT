import SwiftUI

struct EmptyStateView: View {
    @State private var promptIndex = 0
    @State private var rotationTimer: Timer?
    @State private var displayPrompts: [String] = ["Write a poem about Sean."]
    
    let allPrompts = [
        "What should I have for dinner?", "Write a poem about Sean.", "I'm bored. What should I do?",
        "Does this haircut look funny?", "Difference between seal & sea lion?", "Tell me all about NATO.",
        "Best way to cook a steak?", "How to tie a tie easy?", "Best sci-fi movies of all time?",
        "How to make sourdough bread?", "Tips for first-time homebuyers?", "How to change a tire?",
        "How to improve my posture?", "How to solve a Rubik's Cube?", "Best exercises for back pain?",
        "How to write a cover letter?", "How to grow tomatoes?", "Tips for learning Spanish.",
        "How to brew better coffee?", "How to meditate for beginners?", "How to play chess?",
        "How to train for a marathon?", "How to build a PC?", "How to make a paper airplane?",
        "Difference between latte and mocha?", "What is the Joshua Tree Jumper?", "What is the Death Valley Dog?",
        "Why do they call him Puncher Gomez?",
        
        "How can I send this V4?", "How to safely climb Half Dome without cables?", "Best climbing shoes for wide feet?",
        "How to improve grip strength?",
        
        "Why did the UK leave the EU?", "Explain the UN Security Council.", "What is gerrymandering?",
        "Origins of the Cold War?", "How does voting work?", "What is the G20?",
        "Explain the Filibuster.", "History of the Roman Empire.", "Explain the French Revolution.",
        "What is the Monroe Doctrine?", "Explain the Rosetta Stone.", "History of the Internet.",
        
        "Explain Big O notation.", "Python vs Java vs C++?", "What is a binary search tree?",
        "How does HTTP work?", "What is recursion?", "Explain Docker containers.",
        "Git merge vs rebase?", "What is a closure?", "SQL vs NoSQL?",
        "How does DNS work?", "What is a pointer?", "Explain the CAP theorem.",
        "What is a Neural Network?", "Explain the blockchain.", "What is the Turing Test?", "How can I sklearn better?",
        "Two weeks?", "Imagine a world.", "What would you do if there was a zombie in your backyard?", "Pete and Repeat were in a boat.",
        
        "Why is the sky blue?", "Explain relativity simply.", "How do airplanes fly?",
        "What is a black hole?", "What are chakras?", "Define 'existentialism'.",
        "What is the Golden Ratio?", "What is Dark Matter?", "Explain the placebo effect.",
        "What is the Great Barrier Reef?", "Explain the Big Bang Theory.", "What is quantum entanglement?"
    ]

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lyfe Prompts,").font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .shimmer()
                    Text("Kyle Answers.").font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .shimmer()
                }.foregroundColor(.primary.opacity(0.9))
                
                Text(displayPrompts[promptIndex])
                    .font(.system(size: 18, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.8))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .shimmer()
                    .id("p_\(promptIndex)")
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .move(edge: .top))))
            }.padding(.horizontal, 40)
            Spacer()
        }
        .background(
            GeometryReader { geo in
                Image("swirl").renderingMode(.template).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width * 1.5).foregroundColor(.primary).opacity(0.03)
                    .position(x: 0, y: geo.size.height / 2)
            }
        )
        .onAppear {
            displayPrompts = allPrompts.shuffled()
            promptIndex = 0
            
            rotationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    promptIndex = (promptIndex + 1) % displayPrompts.count
                }
            }
        }
        .onDisappear { rotationTimer?.invalidate(); rotationTimer = nil }
    }
}
