import SwiftUI
import EventKit

struct CalendarView: View {
    @State private var events: [CalendarEvent] = []
    @State private var selectedDate = Date()
    @State private var showEventDetails = false
    @State private var selectedEvent: CalendarEvent?
    
    let eventStore = EKEventStore()
    
    var body: some View {
        VStack(spacing: 0) {
            // Date Picker
            VStack(spacing: 12) {
                HStack {
                    Text("Calendar Events")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { refreshEvents() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                }
                
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .onChange(of: selectedDate) { _ in
                    refreshEvents()
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Events List
            ScrollView {
                VStack(spacing: 12) {
                    if events.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No events for this date")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(events) { event in
                            CalendarEventCard(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                    showEventDetails = true
                                }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            requestCalendarAccess()
            refreshEvents()
        }
        .sheet(isPresented: $showEventDetails) {
            if let event = selectedEvent {
                EventDetailsSheet(event: event, isPresented: $showEventDetails)
            }
        }
    }
    
    private func requestCalendarAccess() {
        // requestFullAccessToEvents is required on macOS 14+ (Sonoma)
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                if granted {
                    DispatchQueue.main.async { refreshEvents() }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                if granted {
                    DispatchQueue.main.async { refreshEvents() }
                }
            }
        }
    }
    
    private func refreshEvents() {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        events = ekEvents.map { ekEvent in
            CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                calendar: ekEvent.calendar.title,
                description: ekEvent.notes
            )
        }
    }
}

struct CalendarEventCard: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Label(
                            event.startDate.formatted(date: .omitted, time: .shortened),
                            systemImage: "clock"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Label(
                            event.calendar,
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(from: event.startDate, to: event.endDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let description = event.description, !description.isEmpty {
                Divider()
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = Int(end.timeIntervalSince(start))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct EventDetailsSheet: View {
    let event: CalendarEvent
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Title", value: event.title)
                    DetailRow(label: "Calendar", value: event.calendar)
                    DetailRow(
                        label: "Start",
                        value: event.startDate.formatted(date: .abbreviated, time: .standard)
                    )
                    DetailRow(
                        label: "End",
                        value: event.endDate.formatted(date: .abbreviated, time: .standard)
                    )
                    
                    if let description = event.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Event Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    CalendarView()
}
