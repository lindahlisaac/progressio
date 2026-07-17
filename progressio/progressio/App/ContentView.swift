import SwiftUI

struct ContentView: View {
    @StateObject private var templatesViewModel: TemplateLibraryViewModel
    @StateObject private var weekViewModel: WeekPlannerViewModel

    init() {
        let templatesVM = TemplateLibraryViewModel()
        _templatesViewModel = StateObject(wrappedValue: templatesVM)
        _weekViewModel = StateObject(wrappedValue: WeekPlannerViewModel(templates: templatesVM.templates))
    }

    var body: some View {
        TabView {
            NavigationStack {
                WeekPlannerView(viewModel: weekViewModel, templatesViewModel: templatesViewModel)
            }
            .tabItem {
                Label("Plan", systemImage: "calendar")
            }

            NavigationStack {
                TemplateLibraryView(viewModel: templatesViewModel, weekViewModel: weekViewModel)
            }
            .tabItem {
                Label("Templates", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                HistoryView(weekViewModel: weekViewModel)
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }

            NavigationStack {
                SettingsView(weekViewModel: weekViewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}
