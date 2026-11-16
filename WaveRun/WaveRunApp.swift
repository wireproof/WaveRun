import SwiftUI
import AVFoundation

final class GameAudio {
    static let shared = GameAudio()
    private var music: AVAudioPlayer?
    private var effects: [AVAudioPlayer] = []
    func playMusic(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            music = try AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.volume = 0.55
            music?.play()
        } catch { print("Audio unavailable: \(error)") }
    }
    func effect(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        effects.removeAll { !$0.isPlaying }
        effects.append(player)
        player.play()
    }
}

@main
struct WaveRunApp: App {
    var body: some Scene {
        WindowGroup { GameView().preferredColorScheme(.dark).statusBarHidden() }
    }
}

struct Obstacle: Identifiable {
    let id: Int
    let position: Double
    let lane: Int
    let bonus: Bool
}

final class Game: ObservableObject {
    enum State { case ready, playing, over }
    @Published var state: State = .ready
    @Published var distance = 0.0
    @Published var lane = 0
    @Published var score = 0
    @Published var best = UserDefaults.standard.integer(forKey: "best")
    @Published var colorblind = false
    @Published var hard = false
    @Published var objects: [Obstacle] = []
    private var lastTime: Date?
    private var nextPosition = 4.0
    private var nextID = 0
    private var collected = Set<Int>()

    func start() {
        GameAudio.shared.effect("go")
        GameAudio.shared.playMusic("cantslowdown")
        distance = 0; score = 0; lane = 0; objects = []; collected = []
        nextPosition = 4; nextID = 0; lastTime = nil; state = .playing
        fill()
    }
    func tap() {
        if state == .ready { start() }
        else if state == .playing { lane = 1 - lane; GameAudio.shared.effect("jump") }
    }
    func tick(_ date: Date) {
        guard state == .playing else { lastTime = nil; return }
        guard let previous = lastTime else { lastTime = date; return }
        lastTime = date
        let delta = min(max(date.timeIntervalSince(previous), 0), 0.05)
        let old = distance
        distance += delta * (hard ? 2.0 : 1.55)
        for item in objects where item.position > old && item.position <= distance && item.lane == lane && !collected.contains(item.id) {
            collected.insert(item.id)
            if item.bonus { score += 300; GameAudio.shared.effect("points") } else {
                GameAudio.shared.effect("kill")
                GameAudio.shared.playMusic("cantslowdownmenu")
                state = .over
                best = max(best, score + Int(distance * 100))
                UserDefaults.standard.set(best, forKey: "best")
                break
            }
        }
        objects.removeAll { $0.position < distance - 2 }
        fill()
    }
    var total: Int { score + Int(distance * 100) }
    private func fill() {
        while nextPosition < distance + 20 {
            nextID += 1
            objects.append(Obstacle(id: nextID, position: nextPosition, lane: Int.random(in: 0...1), bonus: nextID % 5 == 0))
            nextPosition += Double.random(in: (hard ? 1.0 : 1.45)...(hard ? 1.6 : 2.15))
        }
    }
}

struct GameView: View {
    @StateObject private var game = Game()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: scenePhase != .active)) { timeline in
                ZStack {
                    Color.black.ignoresSafeArea()
                    Canvas { context, size in draw(context: &context, size: size) }
                        .contentShape(Rectangle())
                        .onTapGesture { game.tap() }
                    VStack {
                        HStack {
                            Text("\(game.total)").font(.system(size: 25, weight: .black, design: .monospaced))
                            Spacer()
                            Text("BEST \(game.best)").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                        }.padding(.horizontal, 30).padding(.top, 12)
                        Spacer()
                    }.allowsHitTesting(false)
                    if game.state != .playing {
                        VStack(spacing: 12) {
                            if game.state == .ready {
                                Image("game_title").resizable().scaledToFit().frame(width: min(geo.size.width * 0.48, 330))
                            } else {
                                Text("\(game.total)").font(.system(size: 48, weight: .black, design: .monospaced))
                            }
                            Text(game.state == .ready ? "PLAY, DIE, REPEAT" : "GAME OVER")
                                .font(.system(size: 14, weight: .bold, design: .monospaced)).tracking(2)
                            Button { game.start() } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: game.state == .ready ? "play.fill" : "arrow.clockwise")
                                    Text(game.state == .ready ? "PLAY" : "PLAY AGAIN")
                                }
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(minWidth: 180, minHeight: 52)
                                .background(Color(red: 0, green: 0.24, blue: 0.27), in: Capsule())
                                .overlay(Capsule().stroke(.cyan, lineWidth: 2))
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            HStack(spacing: 20) {
                                Button(game.hard ? "HARD" : "NORMAL") { game.hard.toggle() }
                                Button(game.colorblind ? "COLORBLIND ON" : "COLORBLIND OFF") { game.colorblind.toggle() }
                            }.font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                            Text("TAP TO SWITCH WAVES · AVOID HAZARDS · COLLECT BONUSES")
                                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                        }.padding(18).background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .onChange(of: timeline.date) { game.tick($0) }
            }
        }.ignoresSafeArea().onAppear { GameAudio.shared.playMusic("cantslowdownmenu") }
    }

    func wave(_ world: Double, lane: Int, height: CGFloat) -> CGFloat {
        let y = lane == 0 ? sin(world * 0.75) * 0.19 + sin(world * 0.29 + 1.3) * 0.08 : sin(world * 0.61 + 2.1) * 0.18 + sin(world * 0.33) * 0.08
        return height * (0.5 + CGFloat(y))
    }
    func draw(context: inout GraphicsContext, size: CGSize) {
        let scale = size.width / 10
        let playerX = size.width * 0.24
        for lane in 0...1 {
            var path = Path()
            for x in stride(from: CGFloat(0), through: size.width + 4, by: 4) {
                let world = game.distance + Double((x - playerX) / scale)
                let p = CGPoint(x: x, y: wave(world, lane: lane, height: size.height))
                if x == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(.white.opacity(0.65)), lineWidth: 2)
        }
        for item in game.objects {
            let x = playerX + CGFloat(item.position - game.distance) * scale
            guard x > -20 && x < size.width + 20 else { continue }
            let y = wave(item.position, lane: item.lane, height: size.height)
            let color: Color = item.bonus ? .green : (game.colorblind ? .orange : .red)
            var segment = Path()
            for dx in stride(from: CGFloat(-13), through: 13, by: 2) {
                let p = CGPoint(x: x + dx, y: wave(item.position + Double(dx / scale), lane: item.lane, height: size.height))
                if dx == -13 { segment.move(to: p) } else { segment.addLine(to: p) }
            }
            context.stroke(segment, with: .color(color), lineWidth: item.bonus ? 5 : 7)
            if game.colorblind && !item.bonus {
                context.draw(Text("×").font(.system(size: 20, weight: .bold)).foregroundColor(.orange), at: CGPoint(x: x, y: y - 18))
            }
        }
        let y = wave(game.distance, lane: game.lane, height: size.height)
        let point = CGPoint(x: playerX, y: y)
        context.addFilter(.shadow(color: .cyan, radius: 10))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(.cyan))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(.white))
    }
}
