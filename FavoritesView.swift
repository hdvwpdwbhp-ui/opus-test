//
//  FavoritesView.swift
//  Tanzen mit Tatiana Drexler
//
//  View for favorite courses
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var courseViewModel: CourseViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                TDGradients.mainBackground
                    .ignoresSafeArea()
                
                if courseViewModel.favoriteCourses.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: TDSpacing.md) {
                            ForEach(courseViewModel.favoriteCourses) { course in
                                NavigationLink(destination: CourseDetailView(course: course)) {
                                    CourseCard(course: course)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(TDSpacing.md)
                    }
                }
            }
            .navigationTitle(T("Favoriten"))
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: TDSpacing.lg) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(T("Keine Favoriten"))
                .font(TDTypography.title2)
                .foregroundColor(.primary)
            
            Text(T("Tippe auf das Herz-Symbol bei einem Kurs, um ihn zu deinen Favoriten hinzuzufügen."))
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TDSpacing.xl)
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(CourseViewModel())
        .environmentObject(StoreViewModel())
}
