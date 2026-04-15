import SwiftUI

extension CalendarView {
    // MARK: - Week Header

    var weekHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { calendarVM.previousWeek() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(calendarVM.weekTitle)
                .font(.subheadline.weight(.semibold))

            if calendarVM.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }

            if !calendarVM.isCurrentWeek {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        calendarVM.goToToday()
                    }
                } label: {
                    Text("이번 주")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: Capsule())
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { calendarVM.nextWeek() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Week Grid (1행 7일)

    var weekGrid: some View {
        VStack(spacing: 4) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(day == "토" ? .blue : day == "일" ? .red : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(calendarVM.daysInWeek, id: \.self) { date in
                    dayCell(date: date)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let dx = value.translation.width
                        if dx < -50 {
                            withAnimation(.easeInOut(duration: 0.2)) { calendarVM.nextWeek() }
                        } else if dx > 50 {
                            withAnimation(.easeInOut(duration: 0.2)) { calendarVM.previousWeek() }
                        }
                    }
            )
        }
    }

    func dayCell(date: Date) -> some View {
        let isSelected = date.isSameDay(as: calendarVM.selectedDate)
        let isToday = date.isToday
        let events = calendarVM.eventDots[date.startOfDay] ?? []

        return Button {
            calendarVM.selectDate(date)
        } label: {
            VStack(spacing: 2) {
                Text(DateFormatters.dayOfMonth.string(from: date))
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)

                HStack(spacing: 2) {
                    if events.contains(.activity(.feeding)) {
                        Circle().fill(AppColors.feedingColor).frame(width: 4, height: 4)
                    }
                    if events.contains(.activity(.sleep)) {
                        Circle().fill(AppColors.sleepColor).frame(width: 4, height: 4)
                    }
                    if events.contains(.activity(.diaper)) {
                        Circle().fill(AppColors.diaperColor).frame(width: 4, height: 4)
                    }
                    if events.contains(.hospitalVisit) {
                        Circle().fill(AppColors.indigoColor).frame(width: 4, height: 4)
                    }
                    if events.contains(.vaccination) {
                        Circle().fill(AppColors.coralColor).frame(width: 4, height: 4)
                    }
                    if events.contains(.todo) {
                        Circle().fill(AppColors.softPurpleColor).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSelected
                    ? Color.accentColor
                    : isToday ? Color.accentColor.opacity(0.1) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
