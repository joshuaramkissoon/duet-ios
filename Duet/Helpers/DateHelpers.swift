//
//  DateHelpers.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 22/05/2025.
//

import Foundation

func timeAgoString(from date: Date) -> String {
    let now = Date()
    let timeInterval = now.timeIntervalSince(date)
    
    if timeInterval < 60 {
        return "now"
    } else if timeInterval < 3600 {
        let minutes = Int(timeInterval / 60)
        return "\(minutes)m"
    } else if timeInterval < 86400 {
        let hours = Int(timeInterval / 3600)
        return "\(hours)h"
    } else {
        let days = Int(timeInterval / 86400)
        if days == 1 {
            return "1d"
        } else if days < 7 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

func friendlyTimeAgoString(from date: Date) -> String {
    let now = Date()
    let calendar = Calendar.current
    let timeInterval = now.timeIntervalSince(date)
    
    // For dates less than a week old, use the regular time ago format
    if timeInterval < 604800 { // 7 days in seconds
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            if days == 1 {
                return "1d"
            } else {
                return "\(days)d"
            }
        }
    } else {
        // For dates older than a week, use friendly date format
        let year = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)
        let formatter = DateFormatter()
        
        if year == currentYear {
            formatter.dateFormat = "dd MMMM" // e.g. "29 May"
        } else {
            formatter.dateFormat = "dd MMMM yyyy" // e.g. "29 May 2024"
        }
        
        return formatter.string(from: date)
    }
}
