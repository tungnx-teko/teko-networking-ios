//
//  JSONSerializationExtensions.swift
//  BLUE
//
//  Created by Tung Nguyen on 12/1/19.
//  Copyright © 2019 Teko. All rights reserved.
//

import Foundation

extension Double {
    
    var isInteger: Bool {
        return self.truncatingRemainder(dividingBy: 1) == 0
    }
    
    var intValue: Int {
        return Int(self)
    }
    
}

extension Dictionary {
    func stringify() -> String {
        let keyValues = compactMap {
            t in
            switch t.value {
            case let str as String:
                return "\"\(t.key)\":\"\(str)\""
            case let dict as Dictionary:
                return "\"\(t.key)\":\"\(dict.stringify())\""
            case let v as Double:
                if v.isInteger {
                    return "\"\(t.key)\":\(v.intValue)"
                }
                return "\"\(t.key)\":\(v)"
            default:
                return "\"\(t.key)\":\(t.value)"
            }
        }.joined(separator: ",")
        return String(format: "{%@}", keyValues)
    }
}

extension NSDictionary {
    public func _bridgeToSwift() -> [NSObject: AnyObject] {
        return self as [NSObject: AnyObject]
    }
}

extension JSONSerialization {
    
    class func data(dictionary dict: [String: Any], options opt: WritingOptions) throws -> Data {
        var jsonStr = [UInt8]()
        var writer = JSONWriter(
            pretty: opt.contains(.prettyPrinted),
            writer: { (str: String?) in
                if let str = str {
                    jsonStr.append(contentsOf: str.utf8)
                }
        })
        let container = dict as NSDictionary
        try writer.serializeJSON(container._bridgeToSwift())
        let count = jsonStr.count
        return Data(bytes: &jsonStr, count: count)
    }
    
}

private struct JSONWriter {
    
    var indent = 0
    let pretty: Bool
    let writer: (String?) -> Void
    
    init(pretty: Bool = false, writer: @escaping (String?) -> Void) {
        self.pretty = pretty
        self.writer = writer
    }
    
    mutating func serializeJSON(_ object: Any?) throws {
        
        guard let obj = object else {
            try serializeNull()
            return
        }
        
        // For better performance, the most expensive conditions to evaluate should be last.
        switch (obj) {
        case let str as String:
            try serializeString(str)
        case let num as Int:
            writer(num.description)
        case let num as Int8:
            writer(num.description)
        case let num as Int16:
            writer(num.description)
        case let num as Int32:
            writer(num.description)
        case let num as Int64:
            writer(num.description)
        case let num as UInt:
            writer(num.description)
        case let num as UInt8:
            writer(num.description)
        case let num as UInt16:
            writer(num.description)
        case let num as UInt32:
            writer(num.description)
        case let num as UInt64:
            writer(num.description)
        case let boolValue as Bool:
            writer(boolValue.description)
        case let array as Array<Any?>:
            try serializeArray(array)
        case let dict as Dictionary<AnyHashable, Any?>:
            try serializeDictionary(dict)
        case let num as Float:
            try serializeFloat(num)
        case let num as Double:
            try serializeFloat(num)
        case let num as Decimal:
            writer(num.description)
        case let num as NSDecimalNumber:
            writer(num.description)
        case is NSNull:
            try serializeNull()
        default:
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey : "Invalid object cannot be serialized"])
        }
    }
    
    mutating func serializeJSON(_ dict: [NSObject: AnyObject]) throws {
        do {
            let hashableDict = dict as Dictionary<AnyHashable, Any?>
            try serializeDictionary(hashableDict)
        } catch {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey : "Invalid object cannot be serialized"])
        }
    }
    
    func serializeString(_ str: String) throws {
        writer("\"")
        for scalar in str.unicodeScalars {
            switch scalar {
            case "\"":
                writer("\\\"") // U+0022 quotation mark
            case "\\":
                writer("\\\\") // U+005C reverse solidus
            case "/":
                writer("\\/") // U+002F solidus
            case "\u{8}":
                writer("\\b") // U+0008 backspace
            case "\u{c}":
                writer("\\f") // U+000C form feed
            case "\n":
                writer("\\n") // U+000A line feed
            case "\r":
                writer("\\r") // U+000D carriage return
            case "\t":
                writer("\\t") // U+0009 tab
            case "\u{0}"..."\u{f}":
                writer("\\u000\(String(scalar.value, radix: 16))") // U+0000 to U+000F
            case "\u{10}"..."\u{1f}":
                writer("\\u00\(String(scalar.value, radix: 16))") // U+0010 to U+001F
            default:
                writer(String(scalar))
            }
        }
        writer("\"")
    }
    
    private func serializeFloat<T: FloatingPoint & LosslessStringConvertible>(_ num: T) throws {
        guard num.isFinite else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey : "Invalid number value (\(num)) in JSON write"])
        }
        var str = num.description
        if str.hasSuffix(".0") {
            str.removeLast(2)
        }
        writer(str)
    }
    
    mutating func serializeNumber(_ num: NSNumber) throws {
        try serializeFloat(num.doubleValue)
    }
    
    mutating func serializeArray(_ array: [Any?]) throws {
        writer("[")
        if pretty {
            writer("\n")
            incAndWriteIndent()
        }
        
        var first = true
        for elem in array {
            if first {
                first = false
            } else if pretty {
                writer(",\n")
                writeIndent()
            } else {
                writer(",")
            }
            try serializeJSON(elem)
        }
        if pretty {
            writer("\n")
            decAndWriteIndent()
        }
        writer("]")
    }
    
    mutating func serializeDictionary(_ dict: Dictionary<AnyHashable, Any?>) throws {
        writer("{")
        if pretty {
            writer("\n")
            incAndWriteIndent()
        }
        
        var first = true
        
        func serializeDictionaryElement(key: AnyHashable, value: Any?) throws {
            if first {
                first = false
            } else if pretty {
                writer(",\n")
                writeIndent()
            } else {
                writer(",")
            }
            
            if let key = key as? String {
                try serializeString(key)
            } else {
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey : "NSDictionary key must be NSString"])
            }
            pretty ? writer(" : ") : writer(":")
            try serializeJSON(value)
        }
        
        let elems = try dict.sorted(by: { a, b in
            guard let a = a.key as? String,
                let b = b.key as? String else {
                    throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSDebugDescriptionErrorKey : "NSDictionary key must be NSString"])
            }
            let options: NSString.CompareOptions = [.numeric, .caseInsensitive, .forcedOrdering]
            let range: Range<String.Index>  = a.startIndex..<a.endIndex
            let locale = NSLocale.system
            
            return a.compare(b, options: options, range: range, locale: locale) == .orderedAscending
        })
        for elem in elems {
            try serializeDictionaryElement(key: elem.key, value: elem.value)
        }
        
        if pretty {
            writer("\n")
            decAndWriteIndent()
        }
        writer("}")
    }
    
    func serializeNull() throws {
        writer("null")
    }
    
    let indentAmount = 2
    
    mutating func incAndWriteIndent() {
        indent += indentAmount
        writeIndent()
    }
    
    mutating func decAndWriteIndent() {
        indent -= indentAmount
        writeIndent()
    }
    
    func writeIndent() {
        for _ in 0..<indent {
            writer(" ")
        }
    }
    
}
