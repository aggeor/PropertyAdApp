# PropertyAdApp

> A mobile app for submitting a new property in xe.gr using prefilled locations

[![Swift Version][swift-image]][swift-url]

## Features

- Enter text in textfields for property title, price and description

- Search and select location from api

- Save cached results for already made search queries for location

- Submit form and display data in sheet

## Requirements

This project was built using **Xcode 26.1.1** and **Swift 6.2**. Mac/macOS is required.


## Installation

1. Install Xcode
2. Clone repository using Xcode

```
git clone https://github.com/aggeor/PropertyAdApp.git
```

3. Create a simulator device to run the app
4. Run the app

## Architecture

**Models**
- `AdFormModel.swift` - Core data model for `Place` to retrieve location data(placeId, mainText, secondaryText)

**Views**
- `AdFormView.swift` - Main form view with texfields, buttons and submitted JSON data sheet

**ViewModels**
- `AdFormViewModel.swift` - Manages form state and actions for `AdFormView`. Handles network requests and caching.

## Testing
Unit tests are included using **XCTest** with dependency injection for network and cache mocking.


- Test Suite - `PropertyAdAppTests`

- Test Mocks - `URLProtocolMock`


## Contact
Aggelos Georgiadis – [LinkedIn](https://www.linkedin.com/in/aggelos-georgiadis-16a1b6189/) - [Github](https://github.com/aggeor/) – ag.gewr@gmail.com

[swift-image]:https://img.shields.io/badge/swift-6.2-orange.svg
[swift-url]: https://swift.org/
