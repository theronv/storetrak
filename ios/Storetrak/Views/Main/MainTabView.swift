import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddTote = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.surface)
        // Selected: accent orange
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.accent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.accent)
        ]
        // Unselected: muted
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.textMuted)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.textMuted)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.activeTab) {
                InboxView()
                    .tabItem { Label("Inbox", systemImage: "tray") }
                    .tag(Tab.inbox)
                TotesView()
                    .tabItem { Label("Totes", systemImage: "shippingbox") }
                    .tag(Tab.totes)
                RoomsView()
                    .tabItem { Label("Rooms", systemImage: "square.grid.2x2") }
                    .tag(Tab.rooms)
                StatsView()
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
                    .tag(Tab.stats)
            }
            .tabViewStyle(.automatic)

            // Toast overlay
            if let toast = appState.toast {
                ToastView(message: toast)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: appState.toast?.id)
                    .zIndex(100)
            }
        }
        .sheet(isPresented: $showAddTote) {
            AddToteSheet(isPresented: $showAddTote)
                .environmentObject(appState)
        }
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        self.overlay(alignment: .bottom) {
            if let msg = toast.wrappedValue {
                ToastView(message: msg)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: msg.id)
            }
        }
    }
}
