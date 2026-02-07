import SwiftUI
import SpriteKit
import AVFoundation

// MARK: - Game Mode Enum
enum GameMode: Identifiable {
    case normal
    case timeTrial

    // Add the required 'id' property for Identifiable
    var id: Self {
        return self
    }
}



// MARK: - Theme colors
fileprivate let themeTextColor = Color(red: 0.8, green: 0.6, blue: 0.4) // Brownish/tan
fileprivate let themePopupBackgroundColor = Color.black.opacity(0.85)
fileprivate let themeButtonBackgroundColor = Color.black.opacity(0.8) // For buttons to match menu buttons
fileprivate let themeAccentShadowColor = Color.purple.opacity(0.5)


// MARK: - Player Profile Data (for total stars)
class PlayerProfile: ObservableObject {
    static let shared = PlayerProfile()
    private static let totalStarsKey = "playerTotalStars_v1" // Added version

    @Published var totalStars: Int

    private init() {
        totalStars = UserDefaults.standard.integer(forKey: PlayerProfile.totalStarsKey)
        print("PlayerProfile initialized. Total stars from UserDefaults: \(totalStars)")
    }

    func addStars(_ stars: Int) {
        if stars > 0 {
            totalStars += stars
            UserDefaults.standard.set(totalStars, forKey: PlayerProfile.totalStarsKey)
            print("PlayerProfile: Added \(stars) stars. New total saved: \(totalStars)")
        } else {
            print("PlayerProfile: Attempted to add \(stars) stars. No change made to totalStars.")
        }
    }

    func spendStars(_ amount: Int) -> Bool {
        if amount > 0 && totalStars >= amount {
            totalStars -= amount
            UserDefaults.standard.set(totalStars, forKey: PlayerProfile.totalStarsKey)
            print("PlayerProfile: Spent \(amount) stars. Remaining: \(totalStars)")
            return true
        }
        print("PlayerProfile: Failed to spend \(amount) stars. Current total: \(totalStars)")
        return false
    }
}


// MARK: - Start Screen
struct StartView: View {
    @State private var showSettings = false // This will now be the "Menu" action
    @State private var showGameModeSelection = false
    @State private var selectedGameMode: GameMode? = nil

    var body: some View {
        ZStack { // Main ZStack for StartView
            // Background Image
            if let backgroundImage = UIImage(named: "astronaut_background") {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                Text("BG Image Missing").foregroundColor(.red)
            }

            // Main Content (Title, Start Button)
            VStack(spacing: 40) {
                ZStack { // Title
                    Text("Lost in Space")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.3))
                        .blur(radius: 7)

                    Text("Lost in Space")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        .shadow(color: .black.opacity(0.7), radius: 5, x: 2, y: 2)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 1, y: 2)
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 3)
                }
                .padding(.top, 50)

                Button("Start Game") { // Start Game Button
                    showGameModeSelection = true
                }
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(Color.black.opacity(0.8))
                .foregroundColor(Color(red: 0.8, green: 0.6, blue: 0.4))
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)

            // Overlay for "Menu" Button (formerly Settings Button)
            VStack {
                HStack {
                    // Assuming your positioning logic placed this HStack correctly.
                    // If it was top-right, a Spacer() would be before the Button.
                    // If top-left, no Spacer() before.

                    Button(action: { // "Menu" Button
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showSettings = true // This still shows the SettingsView, rename @State if "Menu" leads elsewhere
                    }) {
                        // --- TEXT REPLACEMENT ---
                        Text("Menu")
                            // Apply a font style similar to the "Start Game" button's text
                            .font(.title3) // Or .headline, .subheadline. Adjust for balance.
                            .fontWeight(.semibold) // Match "Start Game" weight if desired
                        // --- END TEXT REPLACEMENT ---
                    }
                    // Styling for the "Menu" button
                    .padding(.horizontal, 25) // Adjust padding for text, might need more than icon
                    .padding(.vertical, 12)   // Vertical padding
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(Color(red: 0.8, green: 0.6, blue: 0.4)) // Text color
                    .clipShape(Capsule())
                    .shadow(color: .purple.opacity(0.5), radius: 8, x: 0, y: 4)

                    // YOUR ORIGINAL POSITIONING PADDING
                    .padding(.top, 235) // Your value to move it down

                    // Horizontal positioning:
                    // If this button should be on the RIGHT, add Spacer() before it in this HStack.
                    // Example for RIGHT alignment:
                    // Spacer() // << Add this if you want the "Menu" button on the right
                    // Button(...)
                }
                Spacer() // Pushes the HStack to the top of this VStack
            }

        } // End of Main ZStack for StartView
        .sheet(isPresented: $showGameModeSelection) {
            GameModeSelectionView { mode in
                self.selectedGameMode = mode
                self.showGameModeSelection = false
            }
        }
        .fullScreenCover(item: $selectedGameMode) { mode in
            ContentView(gameMode: mode)
        }
        .sheet(isPresented: $showSettings) { // This sheet is still triggered by the "Menu" button
            SettingsView() // If "Menu" should lead to a different view, change this.
        }
    }
}


struct GameModeSelectionView: View {
    var onModeSelected: (GameMode) -> Void

    // Define your theme colors for reuse
    let buttonBackgroundColor = Color.black.opacity(0.8)
    let buttonTextColor = Color(red: 0.8, green: 0.6, blue: 0.4) // Brownish text
    let accentShadowColor = Color.purple.opacity(0.5)


    var body: some View {
        VStack(spacing: 30) {
            Text("Select Game Mode")
                .font(.largeTitle.bold())
                .padding(.top, 40)
                .foregroundColor(buttonTextColor) // Use theme text color for title
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1) // Optional shadow for title

            Button {
                onModeSelected(.normal)
            } label: {
                Text("Normal Game")
                    .font(.title2)
                    .fontWeight(.semibold) // Keep semibold for consistency
                    .padding()
                    .frame(maxWidth: 250)
                    // --- COLOR MODIFICATIONS FOR NORMAL BUTTON ---
                    .background(buttonBackgroundColor)
                    .foregroundColor(buttonTextColor)
                    // --- END COLOR MODIFICATIONS ---
                    .clipShape(Capsule())
                    .shadow(color: accentShadowColor, radius: 7, x: 0, y: 3) // Consistent shadow
            }

            Button {
                onModeSelected(.timeTrial)
            } label: {
                Text("Time Trial")
                    .font(.title2)
                    .fontWeight(.semibold) // Keep semibold
                    .padding()
                    .frame(maxWidth: 250)
                    // --- COLOR MODIFICATIONS FOR TIME TRIAL BUTTON ---
                    .background(buttonBackgroundColor)
                    .foregroundColor(buttonTextColor)
                    // --- END COLOR MODIFICATIONS ---
                    .clipShape(Capsule())
                    .shadow(color: accentShadowColor, radius: 7, x: 0, y: 3) // Consistent shadow
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Keep the dark background for the sheet itself
        .background(Color.black.opacity(0.9).ignoresSafeArea())
    }
}


// In Views.swift, find your SettingsView struct

struct SettingsView: View {
    @AppStorage("musicVolume") var musicVolume: Double = 0.5
    @AppStorage("sfxVolume") var sfxVolume: Double = 1.0
    @ObservedObject var playerProfile = PlayerProfile.shared

    // Define theme colors (can be passed in or defined locally)
    let themeTextColor = Color(red: 0.8, green: 0.6, blue: 0.4) // Brownish
    let themeAccentColor = Color.yellow // For stars or highlighted values
    let formBackgroundColor = Color.black.opacity(0.85) // Dark background for the form
    let sectionHeaderColor = Color(red: 0.7, green: 0.5, blue: 0.3) // Slightly different brown for headers

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Player Stats").foregroundColor(sectionHeaderColor).fontWeight(.medium)) {
                    HStack {
                        Text("Total Stars Earned")
                            .foregroundColor(themeTextColor) // Apply theme color
                        Spacer()
                        Text("\(playerProfile.totalStars)")
                            .foregroundColor(themeAccentColor) // Accent for star count
                            .fontWeight(.bold)
                    }
                }
                .listRowBackground(Color.black.opacity(0.6)) // Darker background for rows

                Section(header: Text("Audio Settings").foregroundColor(sectionHeaderColor).fontWeight(.medium)) {
                    VStack(alignment: .leading) {
                        Text("Music Volume: \(Int(musicVolume * 100))%")
                            .foregroundColor(themeTextColor) // Apply theme color
                        Slider(value: $musicVolume, in: 0...1, step: 0.01) { _ in
                            NotificationCenter.default.post(name: Notification.Name("VolumeChanged"), object: nil)
                        }
                        .accentColor(themeTextColor) // Slider thumb and track color
                    }

                    VStack(alignment: .leading) {
                        Text("SFX Volume: \(Int(sfxVolume * 100))%")
                            .foregroundColor(themeTextColor) // Apply theme color
                        Slider(value: $sfxVolume, in: 0...1, step: 0.01) { _ in
                            NotificationCenter.default.post(name: Notification.Name("VolumeChanged"), object: nil)
                        }
                        .accentColor(themeTextColor) // Slider thumb and track color
                    }
                }
                .listRowBackground(Color.black.opacity(0.6))

                Section(header: Text("Navigation").foregroundColor(sectionHeaderColor).fontWeight(.medium)) {
                    NavigationLink(destination: HighScoresView(gameMode: .normal)) {
                        Text("High Scores (Normal)")
                            .foregroundColor(themeTextColor) // Apply theme color
                    }
                    NavigationLink(destination: HighScoresView(gameMode: .timeTrial)) {
                        Text("High Scores (Time Trial)")
                            .foregroundColor(themeTextColor) // Apply theme color
                    }
                }
                .listRowBackground(Color.black.opacity(0.6))
            }
            .background(formBackgroundColor.ignoresSafeArea()) // Set overall background for the Form content area
            .scrollContentBackground(.hidden) // For iOS 16+, makes Form background transparent to show our .background
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            // Style the Navigation Bar Title if possible (can be tricky, often needs appearance proxy)
            // For a simple approach, you might need to make a custom nav bar view if default styling isn't enough.
        }
        // Apply accent color to the NavigationView itself, which can influence some elements like back button
        .accentColor(themeTextColor)
        .onChange(of: musicVolume) { _ in
             NotificationCenter.default.post(name: Notification.Name("VolumeChanged"), object: nil)
        }
        .onChange(of: sfxVolume) { _ in
             NotificationCenter.default.post(name: Notification.Name("VolumeChanged"), object: nil)
        }
    }
}

struct HighScoresView: View {
    let gameMode: GameMode
    @State private var scores: [Int] = []

    var body: some View {
        List {
            if scores.isEmpty {
                Text("No high scores yet for \(gameMode == .normal ? "Normal Mode" : "Time Trial"). Play a game!")
                    .foregroundColor(.gray)
            } else {
                ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                    HStack {
                        Text("\(index + 1).")
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(score) \(gameMode == .normal ? "stars" : "rescued")") // Adjusted label
                    }
                }
            }
        }
        .navigationTitle("\(gameMode == .normal ? "Normal Mode" : "Time Trial") High Scores")
        .onAppear {
            scores = SavedScores.load(for: gameMode)
        }
    }
}


struct SavedScores {
    static let normalModeKey = "highScores_stars_normal_v2" // Incremented version if schema changes
    static let timeTrialModeKey = "highScores_timeTrial_v2"

    static func save(score: Int, for mode: GameMode) {
        if score <= 0 && mode == .normal { return }
        if score < 0 && mode == .timeTrial { return } // Time trial score (rescued) should be >= 0

        let key: String
        switch mode {
        case .normal:
            key = normalModeKey
        case .timeTrial:
            key = timeTrialModeKey
        }

        var scores = load(forKey: key)
        scores.append(score)
        scores.sort(by: >)
        UserDefaults.standard.set(Array(scores.prefix(10)), forKey: key)
        print("SavedScores: Saved \(mode) score: \(score). Scores for key \(key): \(Array(scores.prefix(10)))")
    }

    static func load(for mode: GameMode) -> [Int] {
        let key: String
        switch mode {
        case .normal:
            key = normalModeKey
        case .timeTrial:
            key = timeTrialModeKey
        }
        return load(forKey: key)
    }

    private static func load(forKey key: String) -> [Int] {
        let loadedScores = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        print("SavedScores: Loaded scores for key \(key): \(loadedScores)")
        return loadedScores
    }
}


struct ContentView: View {
    @Environment(\.dismiss) var dismiss
    let gameMode: GameMode
    @ObservedObject var playerProfile = PlayerProfile.shared
    @StateObject private var audioManager = AudioManager()

    @State private var levelsCompleted = 0
    @State private var runScore = 0
    @State private var isTrueGameOver = false
    @State private var gameID = UUID()
    @State private var isPaused = false
    @State private var timeRemaining: Int = 15 // For GameScene's individual timer
    
    @State private var showLevelCompleteBanner = false
    @State private var starsEarnedForBanner = 0
    @State private var completedLevelForBanner: Int = 0

    @State private var currentSceneTargetLevel: Int = 1

    // Time Trial specific state
    @State private var timeTrialAstronautsRescued = 0 // This will be the value for 'runScore' in TT display
    @State private var timeTrialDuration: TimeInterval = 60.0
    @State private var timeTrialTimeLeft: TimeInterval = 60.0
    @State private var overallTimeTrialTimer: Timer? = nil

    private func makeGameScene() -> GameScene {
        print("ContentView: makeGameScene for mode: \(gameMode), targetLevel/astronautsSoFar: \(gameMode == .normal ? currentSceneTargetLevel : timeTrialAstronautsRescued)")
        let gameScene = GameScene()
        
        switch gameMode {
        case .normal:
            gameScene.levelToLoadOnAppear = self.currentSceneTargetLevel
            gameScene.onLevelSuccessfullyCompleted = { starsEarnedThisLevel, completedLevelNum in
                print("ContentView: Normal Mode - Level \(completedLevelNum) complete. Stars: \(starsEarnedThisLevel)")
                self.levelsCompleted = completedLevelNum // More direct
                self.runScore += starsEarnedThisLevel
                
                self.starsEarnedForBanner = starsEarnedThisLevel
                self.completedLevelForBanner = completedLevelNum
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.showLevelCompleteBanner = true
                }
                self.isPaused = true
                NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: true)
            }
            gameScene.onGameOver = { // Called on timeout OR when user ends run (normal mode)
                print("ContentView: Normal Mode game over by GameScene. Run score: \(self.runScore)")
                self.playerProfile.addStars(self.runScore)
                SavedScores.save(score: self.runScore, for: .normal)
                self.isTrueGameOver = true
            }
            gameScene.onTimerUpdate = { newTime in self.timeRemaining = newTime }

        case .timeTrial:
            gameScene.levelToLoadOnAppear = 1 // Or more dynamic setup for TT "micro-levels"
            gameScene.onLevelSuccessfullyCompleted = { _, _ in // Stars/level num might not be relevant for TT's GameScene callback
                self.timeTrialAstronautsRescued += 1
                // runScore = self.timeTrialAstronautsRescued // Update runScore for immediate display if needed
                print("ContentView: Time Trial - Astronaut rescued. Total rescued this run: \(self.timeTrialAstronautsRescued)")
                self.isPaused = false
                NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: false)
                self.resetForNextTimeTrialAstronaut()
            }
            gameScene.onGameOver = { // Astronaut timer in GameScene ran out for TT
                print("ContentView: Time Trial - Single astronaut timer ran out. Moving to next.")
                self.isPaused = false
                NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: false)
                self.resetForNextTimeTrialAstronaut() // Still move to next attempt
            }
            gameScene.onTimerUpdate = { newTime in
                self.timeRemaining = newTime // GameScene's timer for the current astronaut
            }
        }
        
        gameScene.size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        gameScene.scaleMode = .aspectFill
        return gameScene
    }
    
    var scene: SKScene { makeGameScene() }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .id(gameID)
                .ignoresSafeArea()

            // UI Overlay
            VStack(alignment: .center, spacing: 0) {
                HStack { // Top Bar
                    VStack(alignment: .leading) {
                        if gameMode == .normal {
                            Text("Level: \(currentSceneTargetLevel)")
                                .font(.title2).bold().foregroundColor(.white).shadow(radius: 1)
                            Text("Stars: \(runScore)")
                                .font(.subheadline).foregroundColor(.yellow).shadow(radius: 1)
                        } else if gameMode == .timeTrial {
                            Text("Time Trial")
                                .font(.title2).bold().foregroundColor(.white).shadow(radius: 1)
                            Text("Rescued: \(timeTrialAstronautsRescued)") // Display TT specific score
                                .font(.subheadline).foregroundColor(.cyan).shadow(radius: 1)
                        }
                    }
                    Spacer()
                    Button { // Pause/Play Button
                        isPaused.toggle()
                        if isPaused && gameMode == .timeTrial {
                            overallTimeTrialTimer?.invalidate()
                        }
                        NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: isPaused)
                        if !isPaused && gameMode == .timeTrial {
                            startTimeTrialTimer()
                        }
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title).foregroundColor(.white).padding(10)
                            .background(Color.black.opacity(0.5)).clipShape(Circle())
                    }
                    .disabled((gameMode == .normal && showLevelCompleteBanner) || isTrueGameOver)

                    Button { dismiss() } label: { // Quit Button
                        Image(systemName: "xmark.circle.fill")
                            .font(.title).foregroundColor(.white).padding(10)
                            .background(Color.red.opacity(0.7)).clipShape(Circle())
                    }
                }
                .padding() // Padding for the top bar HStack

                // Timer Display
                if gameMode == .normal {
                    Text("Time: \(timeRemaining)") // Per-level timer
                        .font(.title).bold()
                        .foregroundColor(timeRemaining <= 5 ? .red : .white)
                        .padding(.top, 5)
                        .opacity(isTrueGameOver || isPaused || showLevelCompleteBanner ? 0 : 1)
                } else if gameMode == .timeTrial {
                    Text("Trial Time: \(Int(timeTrialTimeLeft))s") // Overall trial timer
                        .font(.title).bold()
                        .foregroundColor(timeTrialTimeLeft <= 10 ? .red : .white)
                        .padding(.top, 5)
                        .opacity(isTrueGameOver || isPaused ? 0 : 1)
                }
                
                Spacer() // Pushes UI to top
            }
            .edgesIgnoringSafeArea(.bottom) // Allow UI to go to top, respect bottom safe area


            // Game Over Screen
            if isTrueGameOver {
                VStack(spacing: 20) {
                    Text("Game Over!")
                        .font(.largeTitle).bold().foregroundColor(.white)
                    if gameMode == .normal {
                        Text("Final Score: \(runScore) stars")
                            .font(.title2).foregroundColor(.yellow)
                        Text("Levels Completed: \(levelsCompleted)")
                             .font(.title3).foregroundColor(.white)
                    } else if gameMode == .timeTrial {
                        Text("Astronauts Rescued: \(timeTrialAstronautsRescued)")
                            .font(.title2).foregroundColor(.cyan)
                    }
                    
                    Button("Play Again") { resetGameForNewRun() }
                        .buttonStyle(PauseButtonStyle(color: .green))
                    
                    Button("Back to Menu") { dismiss() }
                        .buttonStyle(PauseButtonStyle(color: .blue))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85)).edgesIgnoringSafeArea(.all)
            }
            
            // Pause Screen
            if isPaused && !isTrueGameOver && !(gameMode == .normal && showLevelCompleteBanner) {
                 PauseView(
                    onResume: {
                        isPaused = false
                        NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: false)
                        if gameMode == .timeTrial { startTimeTrialTimer() }
                    },
                    onRestart: { resetGameForNewRun() },
                    onQuit: { dismiss() }
                 )
            }

            // Level Complete Banner (Normal Mode Only)
            if gameMode == .normal && showLevelCompleteBanner && !isTrueGameOver {
                 VStack {
                    Spacer()
                    LevelCompleteBannerView(
                        completedLevel: completedLevelForBanner,
                        starsEarned: starsEarnedForBanner,
                        onNextLevel: {
                            withAnimation { self.showLevelCompleteBanner = false }
                            self.isPaused = false
                            NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: false)
                            resetForNextLevel()
                        },
                        onEndRun: { // User chose to end run from banner
                            withAnimation { self.showLevelCompleteBanner = false }
                            self.isPaused = false
                            NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: false)
                            NotificationCenter.default.post(name: Notification.Name.UserChoseToEndRun, object: nil)
                        }
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .onAppear {
            print("ContentView onAppear for mode: \(gameMode)")
            
            // MARK: - Start music on first appearance
            audioManager.startMusic()
            
            if gameMode == .timeTrial {
                timeTrialAstronautsRescued = 0 // Reset before starting
                // runScore = 0 // runScore will be updated by rescued astronauts in TT
                timeTrialTimeLeft = timeTrialDuration
                startTimeTrialTimer()
            } else { // Normal mode
                // For a fresh normal game start, ensure these are reset
                // If ContentView is reused without full dismissal, these might carry over
                currentSceneTargetLevel = 1
                levelsCompleted = 0
                runScore = 0
            }
            // A new gameID is typically set when a new game/level starts to force scene recreation.
            // It might be better to set gameID here or in resetGameForNewRun / resetForNextLevel
            // to ensure a fresh scene on first appear if ContentView could be cached.
            // For now, relying on resetGameForNewRun's gameID change.
        }
        .onDisappear {
            print("ContentView onDisappear for mode: \(gameMode)")
            
            // MARK: - Stop music when the user quits
            audioManager.stopMusic()
                        
            
            overallTimeTrialTimer?.invalidate()
            overallTimeTrialTimer = nil
            // Consider pausing GameScene if ContentView fully disappears, to stop its internal timer too
            // This depends on navigation flow. If dismissing to StartView, GameScene is deinited.
        }
        // MARK: - Add this modifier to handle game over
        .onChange(of: isTrueGameOver) { isOver in
            if isOver {
                audioManager.stopMusic()
            }
        }
        
        
    }

    func startTimeTrialTimer() {
        overallTimeTrialTimer?.invalidate()
        guard !isPaused, !isTrueGameOver else { return }
        print("ContentView: Starting overall Time Trial timer. Time left: \(timeTrialTimeLeft)")
        overallTimeTrialTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timerRef in
            if self.isPaused || self.isTrueGameOver {
                timerRef.invalidate()
                print("ContentView: Overall Time Trial timer stopped (pause/game over).")
                return
            }
            self.timeTrialTimeLeft -= 1
            if self.timeTrialTimeLeft <= 0 {
                timerRef.invalidate()
                self.endOfTimeTrial()
            }
        }
    }

    func endOfTimeTrial() {
        if isTrueGameOver { return }
        isTrueGameOver = true
        print("ContentView: End of Time Trial. Rescued: \(timeTrialAstronautsRescued)")
        NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: true) // Pause GameScene
        SavedScores.save(score: timeTrialAstronautsRescued, for: .timeTrial)
    }

    func resetForNextTimeTrialAstronaut() {
        if isTrueGameOver { return } // Don't reset if trial is over
        print("ContentView: Resetting for next Time Trial astronaut.")
        // isPaused should already be false or handled by caller
        // NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: false)
        gameID = UUID() // Recreate GameScene for new astronaut
    }

    func resetGameForNewRun() { // Called from Pause or Game Over to start fresh
        print("ContentView: Resetting game for new run. Mode: \(gameMode)")
        
        // MARK: - Start music when a new run starts
        audioManager.startMusic()
                
        
        overallTimeTrialTimer?.invalidate()
        
        withAnimation { showLevelCompleteBanner = false }
        isPaused = false
        NotificationCenter.default.post(name: Notification.Name("TogglePause"), object: false)

        levelsCompleted = 0
        runScore = 0
        isTrueGameOver = false
        timeRemaining = 15 // Reset UI timer display
        starsEarnedForBanner = 0
        completedLevelForBanner = 0
        
        currentSceneTargetLevel = 1 // For normal mode
        
        // Time Trial specific reset
        timeTrialAstronautsRescued = 0
        timeTrialTimeLeft = timeTrialDuration
        if gameMode == .timeTrial {
            startTimeTrialTimer()
        }
        
        gameID = UUID() // Trigger scene recreation
    }

    func resetForNextLevel() { // Normal Mode
        print("ContentView: Resetting for next level (Normal Mode). Target: \(completedLevelForBanner + 1)")
        isTrueGameOver = false // Ensure not game over
        timeRemaining = 15 // Reset UI display
        
        let nextLevelToLoad = completedLevelForBanner + 1
        currentSceneTargetLevel = nextLevelToLoad
        
        gameID = UUID() // Trigger scene recreation for the next level
    }
}
    
// StarRatingView, LevelCompleteBannerView, PauseView, PauseButtonStyle
// These views should remain unchanged from the previous correct version.
// Make sure they are included in your file.

struct StarRatingView: View {
    let rating: Int
    let maxRating: Int = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxRating, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .foregroundColor(index < rating ? .yellow : .gray.opacity(0.5))
                    .font(.system(size: 28))
            }
        }
    }
}

struct LevelCompleteBannerView: View {
    let completedLevel: Int
    let starsEarned: Int
    var onNextLevel: () -> Void
    var onEndRun: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Level \(completedLevel) Complete!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(themeTextColor) // MODIFIED from .white
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1) // Existing shadow, likely fine

            StarRatingView(rating: starsEarned) // Uses .yellow internally, which is good

            Text(starsEarned > 0 ? "Great Job!" : "Try for more stars next time!")
                .font(.headline)
                .foregroundColor(themeTextColor.opacity(0.9)) // MODIFIED from .white.opacity(0.8), using theme color

            HStack(spacing: 25) {
                Button(action: onNextLevel) {
                    Text("Next Level")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 12)
                        // --- MODIFIED BUTTON STYLE ---
                        .background(themeButtonBackgroundColor) // Was Color.green
                        .foregroundColor(themeTextColor)       // Was Color.white
                        // --- END MODIFIED BUTTON STYLE ---
                        .cornerRadius(10) // Or .clipShape(Capsule()) if you prefer that look from other menus
                        .shadow(color: themeAccentShadowColor.opacity(0.7), radius: 5, x: 0, y: 2) // Consistent shadow
                }

                Button(action: onEndRun) {
                    Text("End Run")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 12)
                        // --- MODIFIED BUTTON STYLE ---
                        .background(themeButtonBackgroundColor) // Was Color.red.opacity(0.9)
                        .foregroundColor(themeTextColor)       // Was Color.white
                        // --- END MODIFIED BUTTON STYLE ---
                        .cornerRadius(10) // Or .clipShape(Capsule())
                        .shadow(color: themeAccentShadowColor.opacity(0.7), radius: 5, x: 0, y: 2) // Consistent shadow
                }
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background( // Banner Background
            RoundedRectangle(cornerRadius: 20)
                .fill(themePopupBackgroundColor) // Already using a dark theme color
                .shadow(color: themeAccentShadowColor, radius: 10, x: 0, y: 5) // Already using theme shadow
        )
        .padding(.horizontal, 30)
        .transition(.move(edge: .top).combined(with: .opacity)) // Transition remains the same
    }
}

struct PauseView: View {
    var onResume: () -> Void
    var onRestart: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Paused")
                .font(.largeTitle).bold()
                .foregroundColor(.white)
            Button("Resume") { onResume() }
                .buttonStyle(PauseButtonStyle(color: .green))
            Button("Restart Run") { onRestart() }
                .buttonStyle(PauseButtonStyle(color: .blue))
            Button("Quit to Menu") { onQuit() }
                .buttonStyle(PauseButtonStyle(color: .red))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
        .edgesIgnoringSafeArea(.all)
    }
}

struct PauseButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .padding()
            .frame(minWidth: 200)
            .background(color)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
