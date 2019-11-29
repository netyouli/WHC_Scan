//
//  ViewController.swift
//  WHC_ScanUnusedClass
//
//  Created by WHC on 17/1/11.
//  Copyright © 2016年 WHC. All rights reserved.
//  Github <https://github.com/netyouli/WHC_Scan>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
// VERSON (1.0.0)
import Cocoa

enum WHCScanProjectType {
    case iOS
    case android
}

enum WHCScanLevel {
    case fast
    case normal
    case carefully
}

class ViewController: NSViewController {
    
    static let kStopScanText = "已经停止了扫描"
    
    @IBOutlet weak var directoryText: NSTextField!
    @IBOutlet weak var threadCountText: NSTextField!
    @IBOutlet weak var openDirectoryButton: NSButton!
    @IBOutlet weak var notUseClassResultView: NSScrollView!
    @IBOutlet var notUseClassResultContentView: NSTextView!
    @IBOutlet weak var resultView: NSScrollView!
    @IBOutlet var resultContentView: NSTextView!
    @IBOutlet weak var scanButton: NSButton!
    @IBOutlet weak var classCountLabel: NSTextField!
    @IBOutlet weak var notUseClassCountLabel: NSTextField!
    @IBOutlet weak var progressLabel: NSTextField!
    @IBOutlet weak var processBar: NSProgressIndicator!
    
    @IBOutlet weak var iOSRadio: NSButton!
    @IBOutlet weak var androidRadio: NSButton!
    
    @IBOutlet weak var fastRadio: NSButton!
    @IBOutlet weak var normalRadio: NSButton!
    @IBOutlet weak var carefullyRadio: NSButton!
    
    private lazy var filePathArray = [String]()
    private lazy var superClassArray = [String]()
    private lazy var classNameArray = [String]()
    
    private lazy var noReferenceImageNameArray = [String]()
    private let fileManager = FileManager.default
    private lazy var scanProjectType = WHCScanProjectType.iOS
    private lazy var scanLevel = WHCScanLevel.normal
    private lazy var notUseClassCount = 0
    private lazy var stopScan = false
    private lazy var group = DispatchGroup()
    private lazy var semaphore = DispatchSemaphore(value: 1)
    private lazy var currentScanIndex = 0
    private lazy var threadCount = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        processBar.maxValue = 1.0
        processBar.minValue = 0.0
        resultContentView.backgroundColor = NSColor(red: 40.0 / 255.0, green: 40.0 / 255.0, blue: 40.0 / 255.0, alpha: 1.0)
        notUseClassResultContentView.backgroundColor = NSColor(red: 40.0 / 255.0, green: 40.0 / 255.0, blue: 40.0 / 255.0, alpha: 1.0)
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    private func setResultContent(content: String?) {
        if content != nil {
            let attrContent = NSMutableAttributedString(string: content!)
            resultContentView.textStorage?.setAttributedString(attrContent)
            resultContentView.textStorage?.font = NSFont.systemFont(ofSize: 14)
            resultContentView.textStorage?.foregroundColor = NSColor.orange
            resultContentView.scroll(NSPoint(x: 0, y: resultContentView.textContainer!.containerSize.height))
        }
    }
    
    private func setNotUseResultContent(content: String?) {
        if content != nil {
            let attrContent = NSMutableAttributedString(string: content!)
            notUseClassResultContentView.textStorage?.setAttributedString(attrContent)
            notUseClassResultContentView.textStorage?.font = NSFont.systemFont(ofSize: 14)
            notUseClassResultContentView.textStorage?.foregroundColor = NSColor.orange
            notUseClassResultContentView.scroll(NSPoint(x: 0, y: notUseClassResultContentView.textContainer!.containerSize.height))
        }
    }
    
    @IBAction func clickCheckUpdate(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://github.com/netyouli/WHC_ScanUnreferenceImageTool")!)
    }
    
    @IBAction func clickAbout(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://github.com/netyouli/")!)
    }
    
    @IBAction func clickOpenDirectory(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            directoryText.stringValue = (openPanel.directoryURL?.path)!
        }
    }
    
    @IBAction func clickRadio(_ sender: NSButton) {
        
    }

    @IBAction func clickStartScan(_ sender: NSButton) {
        stopScan = !stopScan
        sender.title = stopScan ? "停止扫描" : "开始扫描"
        if !stopScan {return}
        if fastRadio.state.rawValue == 1 {scanLevel = .fast}
        else if normalRadio.state.rawValue == 1 {scanLevel = .normal}
        else {scanLevel = .carefully}
        if (iOSRadio.state.rawValue == 1) {
            scanProjectType = .iOS
        }else {
            scanProjectType = .android
        }
        if threadCountText.stringValue.count > 0 {
            threadCount = (threadCountText.stringValue as NSString).integerValue
        }
        threadCount = max(1, threadCount)
        currentScanIndex = 0
        notUseClassCount = 0
        setResultContent(content: "")
        setNotUseResultContent(content: "")
        processBar.doubleValue = 0;
        if directoryText.stringValue.count > 0 {
            filePathArray.removeAll()
            superClassArray.removeAll()
            classNameArray.removeAll()
            processBar.doubleValue = 0;
            progressLabel.stringValue = "扫描之前，需要计算统计项目所有的类，马上开始别着急请耐心等待一小会........^_^"
            DispatchQueue.global().async(execute: {
                let directoryFileNameArray = try! self.fileManager.contentsOfDirectory(atPath: self.directoryText.stringValue)
                self.startCalculateAllClass(directoryFileNameArray, path: self.directoryText.stringValue)
                let classCount = self.classNameArray.count
                DispatchQueue.main.async {
                    self.classCountLabel.stringValue = "项目所有的类: 总计\(classCount)个"
                }
                var classNameListArray = [[String]]()
                let groupCount = classCount / self.threadCount
                let remainCount = classCount % self.threadCount
                for idx in 0 ..< self.threadCount {
                    var classNameList = [String]()
                    for index in idx * groupCount ..< (idx + 1) * groupCount {
                        classNameList.append(self.classNameArray[index])
                    }
                    classNameListArray.append(classNameList)
                }
                if remainCount > 0 {
                    for index in classCount - remainCount ..< classCount {
                        classNameListArray[0].append(self.classNameArray[index])
                    }
                }
                
                let _ = self.group.wait(timeout: DispatchTime.distantFuture)
                for classNameList in classNameListArray {
                    self.startScanThread(classNameList: classNameList, classCount: classCount)
                }
                let _ = self.group.wait(timeout: DispatchTime.distantFuture)
                if self.progressLabel.stringValue == ViewController.kStopScanText {return}
                DispatchQueue.main.async {
                    self.scanButton.title = "开始扫描"
                    self.stopScan = false
                    let alert = NSAlert()
                    alert.messageText = "恭喜您WHC已经帮你扫描完成了,是否要把扫描日志保存到文件？"
                    alert.addButton(withTitle: "保存")
                    alert.addButton(withTitle: "取消")
                    alert.beginSheetModal(for: self.view.window!, completionHandler: { (modalResponse) in
                        if modalResponse.rawValue == 1000 {
                            let savaPanel = NSSavePanel()
                            savaPanel.message = "Choose the path to save the document"
                            savaPanel.allowedFileTypes = ["txt"]
                            savaPanel.allowsOtherFileTypes = false
                            savaPanel.canCreateDirectories = true
                            savaPanel.beginSheetModal(for: self.view.window!, completionHandler: {[unowned self] (code) in
                                if code.rawValue == 1 {
                                    do {
                                        let originTxt = self.notUseClassResultContentView.string.count == 0 ? "" : self.notUseClassResultContentView.string
                                        try originTxt.write(toFile: savaPanel.url!.path, atomically: true, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                                    }catch {
                                        print("写文件异常")
                                    }
                                }
                            })
                        }
                    })
                }
            })
        }else {
            sender.isEnabled = true
            let alert = NSAlert()
            alert.messageText = "WHC提示您请选择扫描项目目录"
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    
    /// 创建扫描线程
    ///
    /// - Parameters:
    ///   - classNameList: 扫描class集合
    ///   - classCount: class总数量
    private func startScanThread(classNameList: [String], classCount: Int) {
        DispatchQueue.global().async(group: group, execute: DispatchWorkItem(block: { 
            for (_, className) in classNameList.enumerated() {
                if !self.stopScan {
                    DispatchQueue.main.sync(execute: {
                        self.progressLabel.stringValue = ViewController.kStopScanText
                    })
                    break
                }
                let _ = self.semaphore.wait(timeout: DispatchTime.distantFuture)
                self.currentScanIndex += 1
                self.semaphore.signal()
                DispatchQueue.main.async(execute: {
                    self.processBar.doubleValue = Double(self.currentScanIndex + 1) / Double(classCount)
                })
                self.execScan(className: className)
            }
        }))
    }
    
    /// 类名分析引擎
    ///
    /// - Parameters:
    ///   - path: 源文件路径
    ///   - file: 文件名称
    /// - Returns: 类名集合
    @discardableResult
    private func analysisEngineClassName(path: String! ,file: String!) -> [String] {
        var classNames = [String]()
        if file != nil && path != nil {
            autoreleasepool {
                let bookData = try! Data(contentsOf: URL(fileURLWithPath: path), options: NSData.ReadingOptions.mappedIfSafe);
                var fileContent = NSString(data: bookData, encoding: String.Encoding.utf8.rawValue)
                if fileContent != nil {
                    if file.hasSuffix(".swift") {
                        var range = fileContent!.range(of: "class")
                        while range.location != NSNotFound {
                            let afterContent = fileContent!.substring(from: range.length + range.location)
                            let returnRange = (afterContent as NSString).range(of: "\n")
                            if returnRange.location != NSNotFound {
                                let firstLineContent = (((afterContent as NSString).substring(to: returnRange.location) as NSString).replacingOccurrences(of: " ", with: "") as NSString).replacingOccurrences(of: "\r", with: "")
                                if !firstLineContent.contains("(") && !firstLineContent.contains("=") && !firstLineContent.contains("?") && !firstLineContent.contains("!") && !firstLineContent.contains(")") {
                                    let colonRange = (firstLineContent as NSString).range(of: ":")
                                    let parenthesesRange = (firstLineContent as NSString).range(of: "{")
                                    let arrowParenthesesRange = (firstLineContent as NSString).range(of: "<")
                                    if arrowParenthesesRange.location != NSNotFound && colonRange.location != NSNotFound {
                                        let className = (firstLineContent as NSString).substring(to: arrowParenthesesRange.location)
                                        if !classNames.contains(className) && !classNameArray.contains(className) {
                                            if className.count > 0 {
                                                classNames.append(className)
                                            }
                                        }
                                    }else if colonRange.location != NSNotFound {
                                        let className = (firstLineContent as NSString).substring(to: colonRange.location)
                                        if !classNames.contains(className) && !classNameArray.contains(className) {
                                            if className.count > 0 {
                                                classNames.append(className)
                                            }
                                        }
                                    }else if parenthesesRange.location != NSNotFound {
                                        let className = (firstLineContent as NSString).substring(to: parenthesesRange.location)
                                        if !classNames.contains(className) && !classNameArray.contains(className) {
                                            if className.count > 0 {
                                                classNames.append(className)
                                            }
                                        }
                                    }else {
                                        if firstLineContent.count > 0 {
                                            let fristChar = String(firstLineContent[..<firstLineContent.startIndex])
                                            if fristChar == fristChar.uppercased() {
                                                let subPartArray = afterContent.components(separatedBy: " ")
                                                if !classNames.contains(firstLineContent) && !classNameArray.contains(firstLineContent) && subPartArray.count == 1 {
                                                    if firstLineContent.count > 0 {
                                                        classNames.append(firstLineContent)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                fileContent = (afterContent as NSString).substring(from: returnRange.location + returnRange.length) as NSString?
                                range = fileContent!.range(of: "class")
                            }else {
                                break
                            }
                        }
                    }else if file.hasSuffix(".m") {
                        var range = fileContent!.range(of: "@implementation")
                        while range.location != NSNotFound {
                            let afterContent = fileContent!.substring(from: range.length + range.location)
                            let returnRange = (afterContent as NSString).range(of: "\n")
                            if returnRange.location != NSNotFound {
                                let firstLineContent = ((afterContent as NSString).substring(to: returnRange.location) as NSString).replacingOccurrences(of: " ", with: "")
                                if firstLineContent.count > 0 {
                                    let parenthesesRange = (firstLineContent as NSString).range(of: "(")
                                    if parenthesesRange.location == NSNotFound {
                                        let bracesRange = (firstLineContent as NSString).range(of: "{")
                                        if bracesRange.location != NSNotFound {
                                            let className = (firstLineContent as NSString).substring(to: bracesRange.location)
                                            if !classNames.contains(className) && !classNameArray.contains(className) {
                                                if className.count > 0 {
                                                    classNames.append(className)
                                                }
                                            }
                                        }else {
                                            if !classNames.contains(firstLineContent) && !classNameArray.contains(firstLineContent) {
                                                if firstLineContent.count > 0 {
                                                    classNames.append(firstLineContent)
                                                }
                                            }
                                        }
                                    }
                                }
                                fileContent = (afterContent as NSString).substring(from: returnRange.location + returnRange.length) as NSString?
                                range = fileContent!.range(of: "@implementation")
                            }else {
                                break
                            }
                        }
                    }else if file.hasSuffix(".java") {
                        var range = fileContent!.range(of: "class")
                        while range.location != NSNotFound {
                            let afterContent = fileContent!.substring(from: range.length + range.location)
                            let returnRange = (afterContent as NSString).range(of: "\n")
                            if returnRange.location != NSNotFound {
                                let firstLineContent = (((afterContent as NSString).substring(to: returnRange.location) as NSString).replacingOccurrences(of: " ", with: "") as NSString).replacingOccurrences(of: "\r", with: "")
                                if !firstLineContent.contains("(") && !firstLineContent.contains("=") && !firstLineContent.contains(")") {
                                    let inheritRange = (firstLineContent as NSString).range(of: "extends")
                                    let implementRange = (firstLineContent as NSString).range(of: "implements")
                                    let parenthesesRange = (firstLineContent as NSString).range(of: "{")
                                    if inheritRange.location != NSNotFound {
                                        let className = (firstLineContent as NSString).substring(to: inheritRange.location)
                                        if !classNames.contains(className) && !classNameArray.contains(className) {
                                            if className.count > 0 {
                                                classNames.append(className)
                                            }
                                        }
                                    }else if implementRange.location != NSNotFound {
                                        let className = (firstLineContent as NSString).substring(to: implementRange.location)
                                        if !classNames.contains(className) && !classNameArray.contains(className) {
                                            if className.count > 0 {
                                                classNames.append(className)
                                            }
                                        }
                                    }else if parenthesesRange.location != NSNotFound {
                                        let className = (firstLineContent as NSString).substring(to: parenthesesRange.location)
                                        if !classNames.contains(className) && !classNameArray.contains(className) {
                                            if className.count > 0 {
                                                classNames.append(className)
                                            }
                                        }
                                    }else {
                                        if firstLineContent.count > 0 {
                                            let fristChar = String(firstLineContent[..<firstLineContent.startIndex])
                                            if fristChar == fristChar.uppercased() {
                                                let subPartArray = afterContent.components(separatedBy: " ")
                                                if !classNames.contains(firstLineContent) && !classNameArray.contains(firstLineContent) && subPartArray.count == 1 {
                                                    if firstLineContent.count > 0 {
                                                        classNames.append(firstLineContent)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                fileContent = (afterContent as NSString).substring(from: returnRange.location + returnRange.length) as NSString?
                                range = fileContent!.range(of: "class")
                            }else {
                                break
                            }
                        }
                    }
                }
            }
            return classNames
        }
        return classNames
    }
    
    private func startCalculateAllClass(_ directoryFileNameArray :[String]!, path: String!) {
        autoreleasepool {
            if directoryFileNameArray != nil {
                for (_, fileName) in directoryFileNameArray.enumerated() {
                    if fileName.hasSuffix(".xcassets") || fileName.hasSuffix(".bundle") {continue}
                    var isDirectory = ObjCBool(true)
                    let pathName = path + "/" + fileName
                    let exist = fileManager.fileExists(atPath: pathName, isDirectory: &isDirectory)
                    if exist && isDirectory.boolValue {
                        let tempDirectoryFileNameArray = try! fileManager.contentsOfDirectory(atPath: pathName)
                        startCalculateAllClass(tempDirectoryFileNameArray, path: pathName)
                    }else {
                        switch scanProjectType {
                            case .android:
                                if fileName.hasSuffix(".java") && fileName != "R.java" && fileName != "BuildConfig.java" {
                                    filePathArray.append(pathName)
                                    classNameArray.append(contentsOf: analysisEngineClassName(path: pathName, file: fileName))
                                }
                            case .iOS:
                                if fileName.hasSuffix(".swift") || fileName.hasSuffix(".m") {
                                    filePathArray.append(pathName)
                                    classNameArray.append(contentsOf: analysisEngineClassName(path: pathName, file: fileName))
                                }else if fileName.hasSuffix(".h") {
                                    autoreleasepool {
                                        let contentData = try! Data(contentsOf: URL(fileURLWithPath: pathName), options: NSData.ReadingOptions.mappedIfSafe);
                                        var fileContent = NSString(data: contentData, encoding: String.Encoding.utf8.rawValue)
                                        if fileContent != nil {
                                            var range = fileContent!.range(of: "@interface")
                                            while range.location != NSNotFound {
                                                let afterContent = fileContent!.substring(from: range.length + range.location)
                                                let returnRange = (afterContent as NSString).range(of: "\n")
                                                if returnRange.location != NSNotFound {
                                                    let firstLineContent = (((afterContent as NSString).substring(to: returnRange.location) as NSString).replacingOccurrences(of: " ", with: "") as NSString).replacingOccurrences(of: "\r", with: "")
                                                    let subArray = firstLineContent.components(separatedBy: ":")
                                                    if subArray.count > 1 {
                                                        let superClass = subArray[1]
                                                        let tempSuperClassArray = superClass.components(separatedBy: "<")
                                                        let handleSuperClassName = tempSuperClassArray.first!.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
                                                        if !superClassArray.contains(handleSuperClassName) {
                                                            superClassArray.append(handleSuperClassName)
                                                        }
                                                    }
                                                    fileContent = (afterContent as NSString).substring(from: returnRange.location + returnRange.length) as NSString?
                                                    range = fileContent!.range(of: "@interface")
                                                }else {
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    private func checkRangeOK(start: NSRange, end: NSRange) -> Bool {
        if start.location != NSNotFound && end.location != NSNotFound {
            return start.location < end.location
        }
        return false
    }
    
    /// 清理垃圾注释内容引擎
    ///
    /// - Parameter content: 源代码
    /// - Returns: 新内容
    private func removeAnnotationContent(_ content: NSString?) -> String {
        if content == nil {return ""}
        let handleFileContent = NSMutableString(string: content!)
        autoreleasepool {
            var annotationStartRange = handleFileContent.range(of: "/*")
            var annotationEndRange = handleFileContent.range(of: "*/")
            if annotationStartRange.location != NSNotFound &&
                annotationEndRange.location != NSNotFound &&
                checkRangeOK(start: annotationStartRange, end: annotationEndRange) {
                var annotationContent = handleFileContent.substring(with: NSMakeRange(annotationStartRange.location + annotationStartRange.length, max(0, annotationEndRange.location - (annotationStartRange.location + annotationStartRange.length))))
                if annotationContent.count == 0 {
                    annotationEndRange = handleFileContent.range(of: "*/", options: .literal, range: NSMakeRange(annotationEndRange.length + annotationEndRange.location, max(0, handleFileContent.length - (annotationEndRange.length + annotationEndRange.location))))
                    if annotationEndRange.location != NSNotFound {
                        annotationContent = handleFileContent.substring(with: NSMakeRange(annotationStartRange.location + annotationStartRange.length, max(0, annotationEndRange.location - (annotationStartRange.location + annotationStartRange.length))))
                    }
                }
                while annotationContent.contains("/*") {
                    handleFileContent.deleteCharacters(in: annotationEndRange)
                    annotationEndRange = handleFileContent.range(of: "*/")
                    if annotationEndRange.location != NSNotFound {
                        annotationContent = handleFileContent.substring(with: NSMakeRange(annotationStartRange.location + annotationStartRange.length, max(0, annotationEndRange.location - (annotationStartRange.location + annotationStartRange.length))))
                    }else {
                        break
                    }
                }
            }
            while annotationStartRange.location != NSNotFound &&
                annotationEndRange.location != NSNotFound &&
                checkRangeOK(start: annotationStartRange, end: annotationEndRange) {
                    handleFileContent.deleteCharacters(in: NSMakeRange(annotationStartRange.location, max(0, annotationEndRange.location - annotationStartRange.location + annotationEndRange.length)))
                    annotationStartRange = handleFileContent.range(of: "/*")
                    annotationEndRange = handleFileContent.range(of: "*/")
                    if annotationStartRange.location != NSNotFound &&
                        annotationEndRange.location != NSNotFound && checkRangeOK(start: annotationStartRange, end: annotationEndRange) {
                        var annotationContent = handleFileContent.substring(with: NSMakeRange(annotationStartRange.location + annotationStartRange.length, max(0, annotationEndRange.location - (annotationStartRange.location + annotationStartRange.length))))
                        if annotationContent.count == 0 {
                            annotationEndRange = handleFileContent.range(of: "*/", options: .literal, range: NSMakeRange(annotationEndRange.length + annotationEndRange.location, max(0, handleFileContent.length - (annotationEndRange.length + annotationEndRange.location))))
                            if annotationEndRange.location != NSNotFound {
                                annotationContent = handleFileContent.substring(with: NSMakeRange(annotationStartRange.location + annotationStartRange.length, max(0, annotationEndRange.location - (annotationStartRange.location + annotationStartRange.length))))
                            }
                        }
                        while annotationContent.contains("/*") {
                            handleFileContent.deleteCharacters(in: annotationEndRange)
                            annotationEndRange = handleFileContent.range(of: "*/")
                            if annotationEndRange.location != NSNotFound {
                                annotationContent = handleFileContent.substring(with: NSMakeRange(annotationStartRange.location + annotationStartRange.length, max(0, annotationEndRange.location - (annotationStartRange.location + annotationStartRange.length))))
                            }else {
                                break
                            }
                        }
                    }
            }
            var startSlashAnnotationRange = handleFileContent.range(of: "//")
            if startSlashAnnotationRange.location != NSNotFound {
                var afterContent = handleFileContent.substring(from: startSlashAnnotationRange.location) as NSString
                var endSlashAnnotationRange = afterContent.range(of: "\n")
                while startSlashAnnotationRange.location != NSNotFound &&
                    endSlashAnnotationRange.location != NSNotFound {
                        handleFileContent.deleteCharacters(in: NSMakeRange(startSlashAnnotationRange.location, endSlashAnnotationRange.location + endSlashAnnotationRange.length))
                        startSlashAnnotationRange = handleFileContent.range(of: "//")
                        if startSlashAnnotationRange.location != NSNotFound {
                            afterContent = handleFileContent.substring(from: startSlashAnnotationRange.location) as NSString
                            endSlashAnnotationRange = afterContent.range(of: "\n")
                        }
                }
            }
        }
        return handleFileContent.replacingOccurrences(of: " ", with: "")
    }
    
    /// 扫描引擎
    ///
    /// - Parameter className: 要扫描的类名
    fileprivate func execScan(className: String) {
        autoreleasepool {
            DispatchQueue.main.sync {
                let originTxt = self.resultContentView.string.count == 0 ? "" : self.resultContentView.string
                let allClassName = ">>>>> " + className + "\n"
                self.setResultContent(content: originTxt + allClassName)
                self.progressLabel.stringValue = className
            }
            var isReference = false
            for filePath in filePathArray {
                let contentData = try! Data(contentsOf: URL(fileURLWithPath: filePath), options: NSData.ReadingOptions.mappedIfSafe);
                let fileContent = NSString(data: contentData, encoding: String.Encoding.utf8.rawValue)
                if fileContent != nil {
                    var handleFileContent = ""
                    switch scanLevel {
                        case .carefully:
                            handleFileContent = removeAnnotationContent(fileContent)
                        case .normal:
                            handleFileContent = fileContent!.replacingOccurrences(of: " ", with: "")
                        case .fast:
                            handleFileContent = fileContent! as String
                    }
                    switch scanProjectType {
                    case .android:
                        if filePath.hasSuffix(".java") {
                            if handleFileContent.contains(className + ".") || handleFileContent.contains(className + "(") || handleFileContent.contains("(" + className + ")") {
                                isReference = true
                                break
                            }else {
                                var range = fileContent!.range(of: className)
                                let contentLenght = fileContent!.length
                                while range.location != NSNotFound {
                                    let fristChar = fileContent!.substring(with: NSMakeRange(max(0, range.location - 1), range.location > 0 ? 1 : 0))
                                    let lastChar = fileContent!.substring(with: NSMakeRange(range.location + range.length, min(1, contentLenght - (range.location + range.length))))
                                    if (fristChar == "," || fristChar == " ") && lastChar == " " {
                                        isReference = true
                                        break
                                    }
                                    range = fileContent!.range(of: className, options: .literal, range: NSMakeRange(range.length + range.location, contentLenght - (range.length + range.location)))
                                }
                                if isReference {
                                    break
                                }
                            }
                        }
                    case .iOS:
                        if filePath.hasSuffix(".swift") {
                            if handleFileContent.contains(className + ".") || handleFileContent.contains(className + "(") || handleFileContent.contains(":" + className) || handleFileContent.contains("as!" + className) || handleFileContent.contains("as?" + className) || handleFileContent.contains("[" + className + "]()") ||
                                handleFileContent.contains(":[" + className + "]") ||
                                handleFileContent.contains("<" + className + ">()") {
                                isReference = true
                                break
                            }
                        }else if filePath.hasSuffix(".m") {
                            if handleFileContent.contains("[" + className) || handleFileContent.contains(className + ".new") || handleFileContent.contains(className + "*") ||
                                handleFileContent.contains("<" + className + ">") || superClassArray.contains(className) {
                                isReference = true
                                break
                            }
                        }
                        break
                    }
                }
            }
            if !isReference {
                DispatchQueue.main.sync(execute: {
                    self.notUseClassCount += 1
                    let originTxt = self.notUseClassResultContentView.string.count == 0 ? "" : self.notUseClassResultContentView.string
                    self.setNotUseResultContent(content: originTxt + ">>>>> " + className + "\n")
                    self.notUseClassCountLabel.stringValue = "项目没使用的类: 总计\(self.notUseClassCount)个"
                })
            }
        }
    }
}

