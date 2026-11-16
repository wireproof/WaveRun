import SwiftUI
import AVFoundation
import CoreText

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
    init() {
        if let url = Bundle.main.url(forResource: "square", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
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

struct JumpTrace {
    let position: Double
    let fromLane: Int
}

final class Game: ObservableObject {
    enum State { case ready, playing, over }
    @Published var state: State = .ready
    @Published var distance = 0.0
    @Published var lane = 0
    @Published var stars = 0
    @Published var jumps: [JumpTrace] = []
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
        distance = 0; stars = 0; lane = 0; objects = []; jumps = []; collected = []
        nextPosition = 4; nextID = 0; lastTime = nil; state = .playing
        fill()
    }
    func tap() {
        if state == .ready { start() }
        else if state == .playing {
            jumps.append(JumpTrace(position: distance, fromLane: lane))
            lane = 1 - lane
            GameAudio.shared.effect("jump")
        }
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
            if item.bonus { stars += 1; GameAudio.shared.effect("points") } else {
                GameAudio.shared.effect("kill")
                GameAudio.shared.playMusic("cantslowdownmenu")
                state = .over
                best = max(best, total)
                UserDefaults.standard.set(best, forKey: "best")
                break
            }
        }
        objects.removeAll { $0.position < distance - 2 }
        fill()
    }
    var distanceScore: Int { Int(distance * 100) }
    var total: Int { distanceScore + stars * 300 }
    func isCollected(_ id: Int) -> Bool { collected.contains(id) }
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
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(game.distanceScore)").font(.custom("FORCEDSQUARE", size: 25)).foregroundStyle(.white.opacity(0.8))
                                Text("★\(game.stars)").font(.custom("FORCEDSQUARE", size: 19)).foregroundStyle(.green)
                            }
                            Spacer()
                        }.padding(.horizontal, 20).padding(.top, 12)
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
        guard size.width > 0, size.height > 0 else { return }
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
        // Replay the player's rail history and its straight cross-rail jumps.
        let leftWorld = game.distance - Double(playerX / scale)
        var traceLane = 0
        var traceStart = 0.0
        for jump in game.jumps {
            if jump.position < leftWorld { traceLane = 1 - jump.fromLane; traceStart = jump.position; continue }
            drawTrace(&context, from: max(traceStart, leftWorld), to: jump.position, lane: traceLane, playerX: playerX, scale: scale, height: size.height)
            let x = playerX + CGFloat(jump.position - game.distance) * scale
            var cross = Path()
            cross.move(to: CGPoint(x: x, y: wave(jump.position, lane: jump.fromLane, height: size.height)))
            cross.addLine(to: CGPoint(x: x, y: wave(jump.position, lane: 1 - jump.fromLane, height: size.height)))
            context.stroke(cross, with: .color(.green.opacity(0.45)), lineWidth: 5)
            context.stroke(cross, with: .color(.white.opacity(0.9)), lineWidth: 2)
            let age = game.distance - jump.position
            if age < 2.0 {
                for i in 0..<14 {
                    let phase = Double(i) * 2.399
                    let spread = CGFloat(age * 25 + Double(i % 4) * 3)
                    let centerY = wave(jump.position, lane: 1 - jump.fromLane, height: size.height)
                    let p = CGRect(x: x + CGFloat(cos(phase)) * spread, y: centerY + CGFloat(sin(phase)) * spread, width: 3, height: 3)
                    context.fill(Path(p), with: .color(.green.opacity(max(0, 1 - age / 2))))
                }
            }
            traceLane = 1 - jump.fromLane; traceStart = jump.position
        }
        drawTrace(&context, from: max(traceStart, leftWorld), to: game.distance, lane: game.lane, playerX: playerX, scale: scale, height: size.height)
        for item in game.objects {
            if game.isCollected(item.id) { continue }
            let x = playerX + CGFloat(item.position - game.distance) * scale
            guard x > -20 && x < size.width + 20 else { continue }
            let y = wave(item.position, lane: item.lane, height: size.height)
            if item.bonus {
                context.draw(Image("pickup_star"), in: CGRect(x: x - 8, y: y - 8, width: 16, height: 16))
                continue
            }
            let color: Color = game.colorblind ? .orange : .red
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
        context.draw(Image("player_star"), in: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
    }
    func drawTrace(_ context: inout GraphicsContext, from: Double, to: Double, lane: Int, playerX: CGFloat, scale: CGFloat, height: CGFloat) {
        guard to > from else { return }
        var path = Path()
        let steps = max(1, Int((to - from) * Double(scale) / 4))
        for i in 0...steps {
            let world = from + (to - from) * Double(i) / Double(steps)
            let p = CGPoint(x: playerX + CGFloat(world - game.distance) * scale, y: wave(world, lane: lane, height: height))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        context.stroke(path, with: .color(.green.opacity(0.45)), lineWidth: 5)
        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 2)
    }
}
