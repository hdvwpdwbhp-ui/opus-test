import SwiftUI

struct CoursePerformanceView: View {
    let course: Course
    @StateObject private var analytics = AppAnalyticsManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var lessons: [Lesson] = []

    var body: some View {
        Group {
            if userManager.canModerateCourse(course.id) {
                content
            } else {
                accessDenied
            }
        }
        .navigationTitle(T("Kurs-Performance"))
        .onAppear {
            lessons = CourseDataManager.shared.lessonsFor(courseId: course.id)
            if lessons.isEmpty {
                lessons = MockData.lessons(for: course.id)
            }
        }
    }

    private var content: some View {
        let metrics = analytics.coursePerformance(for: course, lessons: lessons)
        let lessonStats = analytics.lessonPerformance(for: lessons)

        return ScrollView {
            VStack(alignment: .leading, spacing: TDSpacing.lg) {
                Text(course.title)
                    .font(TDTypography.title2)

                infoCard(
                    title: "Übersicht",
                    rows: [
                        ("Kursaufrufe", "\(metrics.courseViews)"),
                        ("Lektionsaufrufe", "\(metrics.lessonViews)"),
                        ("Gesamt-Watchtime", formatTime(metrics.totalWatchTime)),
                        ("Ø Watchtime/Lektion", formatTime(metrics.avgWatchTimePerLessonView)),
                        ("Ø Watchtime/Kursaufruf", formatTime(metrics.avgWatchTimePerCourseView))
                    ]
                )

                Text(T("Lektionen"))
                    .font(TDTypography.headline)

                ForEach(lessonStats) { stat in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(stat.lessonTitle)
                            .font(TDTypography.subheadline)
                        HStack {
                            Text(T("Views: %@", "\(stat.views)"))
                            Spacer()
                            Text(T("Watchtime: %@", formatTime(stat.watchTime)))
                        }
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                    }
                    .padding(TDSpacing.md)
                    .glassBackground()
                }
            }
            .padding(TDSpacing.md)
        }
    }

    private var accessDenied: some View {
        VStack(spacing: TDSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(T("Kein Zugriff"))
                .font(TDTypography.headline)
            Text(T("Nur Admins und zugewiesene Trainer können diese Statistiken sehen."))
                .font(TDTypography.caption1)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(TDSpacing.lg)
    }

    private func infoCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            Text(title)
                .font(TDTypography.headline)
            ForEach(rows.indices, id: \.self) { idx in
                HStack {
                    Text(rows[idx].0)
                    Spacer()
                    Text(rows[idx].1)
                        .fontWeight(.semibold)
                }
                .font(TDTypography.caption1)
            }
        }
        .padding(TDSpacing.md)
        .glassBackground()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0m"
    }
}

#Preview {
    NavigationStack {
        CoursePerformanceView(course: MockData.courses[0])
    }
}
