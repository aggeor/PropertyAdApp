import SwiftUI

struct AdFormView: View {
    @StateObject private var viewModel = AdFormViewModel()
    @FocusState private var focus: Field?

    enum Field {
        case title
        case location
        case price
        case description
    }

    var body: some View {
        NavigationStack {
            VStack {
                formView
                buttonsView
            }
            .background(.ultraThinMaterial)
            .navigationTitle("New Property")
            .sheet(isPresented: $viewModel.showJSONSheet) {
                // JSON preview will go here
            }
        }
    }
    
    var formView: some View {
        Form {
            Section("Title (required)") {
                TextField("Add property title", text: $viewModel.title)
                    .focused($focus, equals: .title)
            }

            Section("Location (required)") {
                VStack(alignment: .leading) {
                    TextField("Type location...", text: $viewModel.locationText)
                        .focused($focus, equals: .location)

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !viewModel.suggestions.isEmpty {
                        List(viewModel.suggestions, id: \.placeId) { place in
                            Button {
                                viewModel.select(place: place)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(place.mainText).bold()
                                    Text(place.secondaryText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .listStyle(.plain)
                    }
                }
            }

            Section("Price (optional)") {
                TextField("Add property price", text: $viewModel.price)
                    .focused($focus, equals: .price)
            }

            Section("Description (optional)") {
                TextField("Add property description", text: $viewModel.description,  axis: .vertical)
                    .focused($focus, equals: .description)
                    .lineLimit(5...10)
            }
        }
    }

    var buttonsView: some View {
        HStack(spacing: 12) {
            Button("Submit") {
                viewModel.submit()
                focus = nil
            }
            .disabled(!viewModel.canSubmit)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Button("Clear") {
                viewModel.clearForm()
                focus = nil
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
    }
}
