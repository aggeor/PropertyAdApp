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
                jsonSheetView
            }
        }
    }
    
    var formView: some View {
        Form {
            Section("Title (required)") {
                TextField("Add property title", text: $viewModel.title)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .focused($focus, equals: .title)
            }

            Section("Location (required)") {
                VStack(alignment: .leading) {
                    TextField("Type location and select from the list", text: $viewModel.locationText)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .focused($focus, equals: .location)
                        .onChange(of: focus) { oldValue, newValue in
                            viewModel.isLocationFocused = (newValue == .location)
                        }
                    
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !viewModel.suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(viewModel.suggestions) { place in
                                Button {
                                    viewModel.select(place: place)
                                    focus = nil
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(place.mainText).bold()
                                            Text(place.secondaryText)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .frame(maxHeight: 300)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    }
                }
            }

            Section("Price (optional)") {
                TextField("Add property price", text: $viewModel.price)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .focused($focus, equals: .price)
            }

            Section("Description (optional)") {
                TextField("Add property description", text: $viewModel.description,  axis: .vertical)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
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
    
    var jsonSheetView: some View{
        NavigationStack {
            ScrollView {
                Text("Submitted Data")
                Text(viewModel.jsonResult)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        viewModel.showJSONSheet = false
                    }
                }
            }
        }
    }
}
