import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { FeedView() }
                .tabItem { Label("Read", systemImage: "book.pages") }
            NavigationStack { MyNoteView() }
                .tabItem { Label("My Note", systemImage: "leaf") }
            NavigationStack { CommunityImpactView() }
                .tabItem { Label("Our Impact", systemImage: "globe.americas") }
            NavigationStack { AccountView() }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}
