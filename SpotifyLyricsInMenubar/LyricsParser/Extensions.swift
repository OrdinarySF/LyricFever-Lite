//
//  Extensions.swift
//  SpotlightLyrics
//
//  Created by Scott Rong on 2017/7/28.
//  Copyright © 2017 Scott Rong. All rights reserved.
//

import Foundation

extension CharacterSet {
    public static var quotes = CharacterSet(charactersIn: "\"'")
}

extension String {
    public func emptyToNil() -> String? {
        return self == "" ? nil : self
    }
    
    public func blankToNil() -> String? {
        return self.trimmingCharacters(in: .whitespacesAndNewlines) == "" ? nil : self
    }
    
    // 字符串相似度计算 (Levenshtein distance)
    func distance(between target: String) -> Double {
        let source = self.lowercased()
        let target = target.lowercased()
        
        if source == target { return 1.0 }
        
        let sourceLength = source.count
        let targetLength = target.count
        
        if sourceLength == 0 || targetLength == 0 { return 0.0 }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: targetLength + 1), count: sourceLength + 1)
        
        for i in 1...sourceLength {
            matrix[i][0] = i
        }
        
        for j in 1...targetLength {
            matrix[0][j] = j
        }
        
        for i in 1...sourceLength {
            for j in 1...targetLength {
                if source[source.index(source.startIndex, offsetBy: i - 1)] == target[target.index(target.startIndex, offsetBy: j - 1)] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = Swift.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + 1)
                }
            }
        }
        
        let maxLength = max(sourceLength, targetLength)
        return 1.0 - Double(matrix[sourceLength][targetLength]) / Double(maxLength)
    }
}
