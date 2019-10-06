//
//  TmpNoteViewController.swift
//  tmpNote
//
//  Created by BUDDAx2 on 9/24/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import Cocoa
import SpriteKit
import AppKit


class TmpNoteViewController: NSViewController, NSTextViewDelegate {

    enum Mode: Int {
        case text
        case sketch
    }
    
    static let kFontSizeKey = "FontSize"
    static let kFontSizes = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    static var defaultFontSize: Int {
        return kFontSizes[4]
    }

    static let kPreviousSessionTextKey = "PreviousSessionText"
    static let kPreviousSessionModeKey = "PreviousMode"
    static let kPreviousPathKey = "PreviousFilePath"
    static let kFilePathsKey = "FilePaths"
    
    var drawingScene: DrawingScene?
    var skview: SKView?
    
    var tmpLockMode = false
    
    @IBOutlet weak var hidableHeaderView: NSVisualEffectView!
    @IBOutlet weak var headerView: HeaderView! {
        didSet {
            headerView.onMouseExitedClosure = { [weak self] in
                DispatchQueue.main.async {
                    self?.hidableHeaderView.isHidden = true
                }
            }
            headerView.onMouseEnteredClosure = { [weak self] in
                DispatchQueue.main.async {
                    self?.hidableHeaderView.isHidden = false
                }
            }

        }
    }
    @IBOutlet weak var drawButton: NSButton!
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var textareaScrollView: NSScrollView!
    @IBOutlet weak var drawingView: NSView!
    @IBOutlet var appMenu: NSMenu!
    @IBOutlet weak var notesListMenu: NSPopUpButton!
    @IBOutlet var textView: NSTextView! {
        didSet {
            textView.delegate = self
            setupTextView()
            loadPreviousText()
        }
    }
    @IBOutlet weak var lockButton: NSButton! {
        didSet {
            let isLocked = UserDefaults.standard.bool(forKey: "locked")
            lockButton.image = isLocked ? NSImage(named: "NSLockLockedTemplate") : NSImage(named: "NSLockUnlockedTemplate")
            lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
        }
    }
    
    var lines = [SKShapeNode]()
    var currentMode: Mode = .text {
        didSet {
            let icon = currentMode == .sketch ? NSImage(named: "draw_filled") : NSImage(named: "draw")
            drawButton.state = currentMode == .sketch ? .on : .off
            drawButton.image = icon
        }
    }
    var currentNote: Note? {
        didSet {
            if let oldPath = oldValue?.url {
                TmpNoteViewController.save(text: textView.string, to: oldPath)
            }
            
            if let newPath = currentNote?.url {
                textView.string = TmpNoteViewController.loadText(from: newPath)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        shareButton.sendAction(on: .leftMouseDown)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        let prevModeInt = UserDefaults.standard.integer(forKey: TmpNoteViewController.kPreviousSessionModeKey)
        if let mode = Mode(rawValue: prevModeInt) {
            switch mode {
            case .text:
                textView?.window?.makeKeyAndOrderFront(self)
                removeDrawScene()
            case .sketch:
                createDrawScene()
            }
        }
    }
    
    override func viewWillDisappear() {
        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true

        super.viewWillDisappear()
    }
    
    func createDrawScene() {
        skview = SKView(frame: drawingView.bounds)
        drawingView.addSubview(skview!)
        drawingScene = SKScene(fileNamed: "DrawingScene") as? DrawingScene
        drawingScene?.mainController = self
        drawingScene?.contentDidChangeCallback = contentDidChange
        skview?.presentScene(drawingScene)
        
        drawingScene?.load()
        
        skview?.backgroundColor = .clear
        skview?.allowsTransparency = true
        drawingView.backgroundColor = .clear
        drawingScene?.backgroundColor = .clear
        
        textareaScrollView.isHidden = true
        drawingView.isHidden = false
        
        currentMode = .sketch
    }
    
    func removeDrawScene() {
        drawingScene?.removeFromParent()
        skview?.removeFromSuperview()
        
        textareaScrollView.isHidden = false
        drawingView.isHidden = true
        
        currentMode = .text
    }
    
    @IBAction func toggleDrawingMode(_ sender: Any) {
        save()
        
        switch currentMode {
            case .text:
                createDrawScene()
            case .sketch:
                removeDrawScene()
        }
    }
    
    @IBAction func noteDidChange(_ sender: NSPopUpButton) {

//        if let cNote = currentNote {
//            TmpNoteViewController.save(text: textView.string, to: cNote.url)
//        }
        
        guard let title = sender.selectedItem?.title else { return }
        let notes = TmpNoteViewController.loadNotesList()
        if let note = notes.filter({ $0.name == title }).first {
//            let text = TmpNoteViewController.loadText(from: note.url)
//            textView.string = text
            currentNote = note
        }
    }
    
    func copyContent() {
        if drawingView.isHidden == false {
            
            if let image = imageFromScene() {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
            
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(textView.string, forType: NSPasteboard.PasteboardType.string)
    }
    
    func imageFromScene() -> NSImage? {
        var isDarkTheme = false
        if #available(OSX 10.14, *) {
            isDarkTheme = NSAppearance.current.name == NSAppearance.Name.darkAqua || NSAppearance.current.name == NSAppearance.Name.vibrantDark
        } else {
            isDarkTheme = NSAppearance.current.name == NSAppearance.Name.vibrantDark
        }
        drawingScene?.backgroundColor = isDarkTheme ? .darkGray : .white
        let texture = skview?.texture(from: drawingScene!)
        drawingScene?.backgroundColor = .clear

        if let texture = texture {
            let img2 = texture.cgImage()
            let image = NSImage(cgImage: img2, size: drawingScene!.size)

            return image
        }

        return nil
    }
    
    @objc fileprivate func setupTextView() {

        let fontSize = UserDefaults.standard.value(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        setFontSize(size: CGFloat(fontSize))
    }
    
    fileprivate func setFontSize(size: CGFloat) {
        let font = NSFont.systemFont(ofSize: size)
        textView.font = font
    }
        
    func loadPreviousText() {
        loadSubstitutions()
                
        notesListMenu.menu?.removeAllItems()
        let paths = TmpNoteViewController.loadNotesList()
        paths.forEach { [weak self] note in
            self?.notesListMenu.menu?.addItem(withTitle: note.name, action: nil, keyEquivalent: "")
        }
        
        if paths.isEmpty {
            self.notesListMenu.menu?.addItem(withTitle: "tmp", action: nil, keyEquivalent: "")
        } else {
            if let previousPath = UserDefaults.standard.string(forKey: TmpNoteViewController.kPreviousPathKey) {
                if let fileName = previousPath.fileName() {
                    currentNote = Note(name: fileName, path: previousPath, url: URL(fileURLWithPath: previousPath))
                    notesListMenu.selectItem(withTitle: currentNote!.name)
                }
            }
        }
        
//        textView.string = TmpNoteViewController.loadText()
        textView.checkTextInDocument(nil)
        
        loadSketch()
    }
    
    func loadSketch() {
        lines = TmpNoteViewController.loadSketch()
        
        contentDidChange()
    }
    
    static func loadNotesList() -> [Note] {
        if let paths = UserDefaults.standard.array(forKey: TmpNoteViewController.kFilePathsKey) as? [String] {
            return paths.compactMap { path in
                if let fileName = path.fileName() {
                    return Note(name: fileName, path: path, url: URL(fileURLWithPath: path))
                }
                return nil
            }
        }
        
        return [Note]()
    }
    
    static func loadText(from path: URL) -> String {
        debugPrint("Loading: " + path.absoluteString)

        var text = ""
        
        do {
            let savedText = try String(contentsOf: path, encoding: .utf8)
            text = savedText
        } catch {
            debugPrint(error.localizedDescription)
        }

        return text

    }
    
    static func loadText() -> String {
        var text = ""
        
        // get URL to the the documents directory in the sandbox
        if let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Notes") {
            // add a filename
            let fileUrl = URL(fileURLWithPath: "foo", relativeTo: documentsUrl).appendingPathExtension("txt")
            do {
                let savedText = try String(contentsOf: fileUrl, encoding: .utf8)
                text = savedText
            } catch {
                debugPrint(error.localizedDescription)
            }
        }

        return text
    }
    
    func loadSubstitutions() {
        textView.isAutomaticDashSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartDashes") != nil ? UserDefaults.standard.bool(forKey: "SmartDashes") : true
        textView.isAutomaticSpellingCorrectionEnabled = UserDefaults.standard.object(forKey: "SmartSpelling") != nil ? UserDefaults.standard.bool(forKey: "SmartSpelling") : true
        textView.isAutomaticTextReplacementEnabled = UserDefaults.standard.object(forKey: "SmartTextReplacing") != nil ? UserDefaults.standard.bool(forKey: "SmartTextReplacing") : true
        textView.isAutomaticDataDetectionEnabled = UserDefaults.standard.object(forKey: "SmartDataDetection") != nil ? UserDefaults.standard.bool(forKey: "SmartDataDetection") : true
        textView.isAutomaticQuoteSubstitutionEnabled = UserDefaults.standard.object(forKey: "SmartQuotes") != nil ? UserDefaults.standard.bool(forKey: "SmartQuotes") : true
        textView.isAutomaticLinkDetectionEnabled = UserDefaults.standard.object(forKey: "SmartLinks") != nil ? UserDefaults.standard.bool(forKey: "SmartLinks") : true
    }

    static func loadSketch() -> [SKShapeNode] {
        var lines = [SKShapeNode]()
        
        if let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Sketches") {

            let fileUrl = URL(fileURLWithPath: "sketch", relativeTo: documentsUrl).appendingPathExtension("txt")

            do {
                let data = try Data(contentsOf: fileUrl)
                if let encodedLines = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Data] {
                    for data in encodedLines {
                        if let bp = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSBezierPath {
                            let path = bp.cgPath
                            let newLine = SKShapeNode(path: path)
                            newLine.strokeColor = .textColor
                            lines.append(newLine)
                        }
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
        
        return lines
    }

    @IBAction func lockAction(_ sender: Any) {
        let isLocked = UserDefaults.standard.bool(forKey: "locked")
        UserDefaults.standard.set(!isLocked, forKey: "locked")
        lockButton.image = isLocked ? NSImage(named: "NSLockUnlockedTemplate") : NSImage(named: "NSLockLockedTemplate")
        lockButton.toolTip = isLocked ? "Do Not Hide on Deactivate" : "Hide on Deactivate"
    }
    
    static func save(text: String, to path: URL) {
        debugPrint("Saving to: " + path.absoluteString)
        
        do {
            try text.write(to: path, atomically: true, encoding: .utf8)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    func save() {
        if let cNote = currentNote {
            TmpNoteViewController.save(text: textView.string, to: cNote.url)
            
            UserDefaults.standard.set(cNote.path, forKey: TmpNoteViewController.kPreviousPathKey)
        }
        
//        // get URL to the the documents directory in the sandbox
//        if let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Notes") {
//            // add a filename
//            let fileUrl = URL(fileURLWithPath: "foo", relativeTo: documentsUrl).appendingPathExtension("txt")
//            // write to it
//            do {
//                try textView.string.write(to: fileUrl, atomically: true, encoding: .utf8)
//            } catch {
//                debugPrint(error.localizedDescription)
//            }
//        }
        UserDefaults.standard.set(currentMode.rawValue, forKey: TmpNoteViewController.kPreviousSessionModeKey)
        
        saveSubstitutions()
        
        saveSketch()
    }
    
    func saveSubstitutions() {
        let dashes = textView.isAutomaticDashSubstitutionEnabled
        let spelling = textView.isAutomaticSpellingCorrectionEnabled
        let textReplacing = textView.isAutomaticTextReplacementEnabled
        let dataDetection = textView.isAutomaticDataDetectionEnabled
        let quotes = textView.isAutomaticQuoteSubstitutionEnabled
        let links = textView.isAutomaticLinkDetectionEnabled
        
        UserDefaults.standard.set(dashes, forKey: "SmartDashes")
        UserDefaults.standard.set(spelling, forKey: "SmartSpelling")
        UserDefaults.standard.set(textReplacing, forKey: "SmartTextReplacing")
        UserDefaults.standard.set(dataDetection, forKey: "SmartDataDetection")
        UserDefaults.standard.set(quotes, forKey: "SmartQuotes")
        UserDefaults.standard.set(links, forKey: "SmartLinks")
    }
    
    func saveSketch() {
        let paths:[CGPath] = lines.compactMap { $0.path }
        
        var encodedLines = [Data]()
        for path in paths {
            let bp = NSBezierPath()
            
            let points:[CGPoint] = path.getPathElementsPoints()
            if points.count > 0 {
                
                bp.move(to: points.first!)
                for i in 1..<points.count {
                    bp.line(to: points[i])
                }
                
                let arch = NSKeyedArchiver.archivedData(withRootObject: bp)
                encodedLines.append(arch)
            }
        }
        
        if let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Sketches") {
            // add a filename
            let fileUrl = URL(fileURLWithPath: "sketch", relativeTo: documentsUrl).appendingPathExtension("txt")
            // write to it
            do {
                let data = NSKeyedArchiver.archivedData(withRootObject: encodedLines)
                try data.write(to: fileUrl)
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    
    ///Close popover if Esc key is pressed
    override func cancelOperation(_ sender: Any?) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.closePopover()
    }
    
    @IBAction func showAppMenu(_ sender: NSButton) {
        let p = NSPoint(x: 0, y: sender.frame.height)
        appMenu.popUp(positioning: nil, at: p, in: sender)
    }

    @IBAction func changeFontSize(_ sender: NSSegmentedControl) {
        if sender.indexOfSelectedItem == 0 {
            decreaseFontSize()
        }
        else {
            increaseFontSize()
        }
    }
    
    func decreaseFontSize() {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.firstIndex(of: fontSize) else { return }
        let nextFontSize = currentFontIndex-1 > 0 ? TmpNoteViewController.kFontSizes[currentFontIndex-1] : TmpNoteViewController.kFontSizes.first

        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    func increaseFontSize() {
        let fontSize = UserDefaults.standard.object(forKey: TmpNoteViewController.kFontSizeKey) as? Int ?? TmpNoteViewController.defaultFontSize
        
        guard let currentFontIndex = TmpNoteViewController.kFontSizes.firstIndex(of: fontSize) else { return }
        let nextFontSize = currentFontIndex+1 < TmpNoteViewController.kFontSizes.count ? TmpNoteViewController.kFontSizes[currentFontIndex+1] : TmpNoteViewController.kFontSizes.last
        
        if let newFontSize = nextFontSize {
            UserDefaults.standard.set(newFontSize, forKey: TmpNoteViewController.kFontSizeKey)
            self.setFontSize(size: CGFloat(newFontSize))
        }
    }
    
    func deleteDialog(question: String, text: String) -> NSAlert {
        
        // Prevent popup from hiding while the dialog is visible
        tmpLockMode = UserDefaults.standard.bool(forKey: "locked")
        UserDefaults.standard.set(true, forKey: "locked")

        
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert
    }
    
    @IBAction func clearAction(_ sender: Any) {
        
        var message: (String, String)
        switch currentMode {
            case .text:
                message = ("Delete the note?", "Are you sure you would like to delete the note?")
            case .sketch:
                message = ("Delete the drawing?", "Are you sure you would like to delete the drawing?")
        }
        
        deleteDialog(question: message.0, text: message.1).beginSheetModal(for: self.view.window!, completionHandler: { [weak self] (modalResponse) -> Void in
            guard let strongSelf = self else { return }
            
            if let lock = self?.tmpLockMode {
                UserDefaults.standard.set(lock, forKey: "locked")
            }
            
            if modalResponse == .alertFirstButtonReturn {
                
                if let mode = self?.currentMode {
                    switch mode {
                        case .text:
                            if let textLength = strongSelf.textView.textStorage?.length {
                                strongSelf.textView.insertText("", replacementRange: NSRange(location: 0, length: textLength))
                                self?.save()
                            }

                        case .sketch:
                            self?.drawingScene?.clear()
                    }
                    
                    self?.contentDidChange()
                }
            }
        })
    }
    
    @IBAction func shareAction(_ sender: NSButton) {
        var sharedItems = [Any]()
        
        if drawingView.isHidden == false {
            if let image = imageFromScene() {
                sharedItems = [image]
            }
        }
        else {
            sharedItems = [textView.string];
        }
        
        let servicePicker = NSSharingServicePicker(items: sharedItems)
        servicePicker.delegate = self
        servicePicker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
    
    @IBAction func openPreferences(_ sender: Any) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        (appDelegate.preferences.contentViewController as? GeneralViewController)?.delegate = self
        appDelegate.openPreferences()
    }
    
    @IBAction func terminateApp(_ sender: Any) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.quitAction()
    }
    
    func textDidChange(_ notification: Notification) {
        contentDidChange()
    }
    
    func contentDidChange() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let isTextContent = textView.string.isEmpty == false
        let isSketchContent = lines.count > 0
        appDelegate.toggleMenuIcon(fill: (isTextContent || isSketchContent))
    }
}

// MARK: NSSharingServicePickerDelegate
extension TmpNoteViewController: NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        
        guard let image = NSImage(named: "copy") else {
            return proposedServices
        }
        
        var share = proposedServices
        let plainText = NSSharingService(title: "Copy", image: image, alternateImage: image, handler: {
            self.copyContent()
        })
        share.insert(plainText, at: 0)
        
        return share
    }
}

extension TmpNoteViewController {
    
    static func freshController() -> TmpNoteViewController {
        
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = "TmpNoteViewController"
        guard let vc = storyBoard.instantiateController(withIdentifier: identifier) as? TmpNoteViewController else {
            
            fatalError("Can't instantiate TmpNoteViewController. Check Main.storyboard")
        }
        
        return vc
    }
}

extension TmpNoteViewController: PreferencesDelegate {
    
    func settingsDidChange() {
        setupTextView()
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.toggleMenuIcon(fill: textView.string.isEmpty == false)
    }
}

extension String {
    
    func fileName() -> String? {
        let url = URL(fileURLWithPath: self)
        
        let fileNameWithExtension = url.lastPathComponent
        let fileExtension = url.pathExtension
        let fileName = fileNameWithExtension.replacingOccurrences(of: "." + fileExtension, with: "")
        
        return fileName
    }
}
