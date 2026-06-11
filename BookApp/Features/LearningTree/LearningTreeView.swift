import SwiftUI
import SwiftData

/// The "Learn" tab. Lists the courses a user has built and offers a button to
/// build a new one from a book that has key learnings. A course is a
/// Duolingo-style tree over a book's ideas (PLAN.md §4.3); the win condition is
/// retention, so nothing here punishes a missed day.
struct LearningTreeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdAt, order: .reverse) private var courses: [Course]
    @Query private var books: [Book]

    @State private var picking = false
    @State private var selectedCourse: Course?

    private var buildableBooks: [Book] {
        books.filter { !($0.keyLearnings ?? []).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if courses.isEmpty {
                    emptyState
                } else {
                    courseList
                }
            }
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .navigationTitle("Learn")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        picking = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    .disabled(buildableBooks.isEmpty)
                    .accessibilityLabel("Build a course from a book")
                }
            }
            .sheet(isPresented: $picking) {
                BookCoursePicker(books: buildableBooks) { book in
                    picking = false
                    build(from: book)
                }
            }
            .navigationDestination(item: $selectedCourse) { course in
                CourseDetailView(course: course)
            }
        }
    }

    // MARK: - Course list

    private var courseList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                buildButton
                ForEach(courses) { course in
                    Button {
                        selectedCourse = course
                    } label: {
                        courseRow(course)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.m)
        }
    }

    private func courseRow(_ course: Course) -> some View {
        let nodes = course.orderedNodes
        return HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 44, height: 44)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.m))
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)
                Text("\(nodes.count) steps · \(course.xp) XP")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.l))
    }

    private var buildButton: some View {
        Button {
            picking = true
        } label: {
            Label("Build a course from a book", systemImage: "plus.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background(Theme.Palette.accent)
                .foregroundStyle(Theme.Palette.appBackground)
                .clipShape(Capsule())
        }
        .disabled(buildableBooks.isEmpty)
        .opacity(buildableBooks.isEmpty ? 0.5 : 1)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "graduationcap")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
                .padding(.bottom, Theme.Spacing.xs)
            Text("Turn a book into a course")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("A course lays a book's key ideas out as a path of short lessons and checkpoint quizzes. Clear a step to unlock the next, at your own pace. No streak to protect, no penalty for a day away.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            if buildableBooks.isEmpty {
                Text("Add key learnings to a book first, then build its course here.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.xs)
            } else {
                Button {
                    picking = true
                } label: {
                    Label("Build a course from a book", systemImage: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.s + 2)
                        .background(Theme.Palette.accent)
                        .foregroundStyle(Theme.Palette.appBackground)
                        .clipShape(Capsule())
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - Actions

    private func build(from book: Book) {
        let store = CourseStore(context: modelContext)
        if let course = store.buildCourse(from: book) {
            selectedCourse = course
        }
    }
}

/// A simple picker listing books that have key learnings, for building a course.
private struct BookCoursePicker: View {
    let books: [Book]
    let onPick: (Book) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(books) { book in
                Button {
                    onPick(book)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("\(book.author) · \((book.keyLearnings ?? []).count) ideas")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            .navigationTitle("Pick a book")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        LearningTreeView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
