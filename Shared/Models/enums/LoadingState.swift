//
//  LoadingState.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}
