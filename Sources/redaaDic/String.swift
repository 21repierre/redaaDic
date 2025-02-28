//
//  String.swift
//  
//
//  Created by Pierre on 2025/02/28.
//

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
