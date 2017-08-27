//
//  ArrayChangeManager.swift
//  ExampleArrayChangeManager
//
//  Created by Beloizerov on 27.08.17.
//  Copyright © 2017 Home. All rights reserved.
//

import Foundation

protocol ArrayChangeManagerDelegate: class {
    
    func objectAtIndex<T: Comparable>(_ change: ArrayChangeManager<T>.ObjectChange, manager:  ArrayChangeManager<T>)
    
}

class ArrayChangeManager<T: Comparable>: Collection {
    
    weak var delegate: ArrayChangeManagerDelegate?
    
    // MARK: - Objects
    
    private let accessQueue = DispatchQueue(label: "accessQueue", attributes: .concurrent)
    private var _objects = [[T]]()
    
    subscript(section: Int) -> [T] {
        var result = [T]()
        accessQueue.sync {
            guard section >= 0, section < _objects.count else { return }
            result = _objects[section]
        }
        return result
    }
    
    var objects: [[T]] {
        get {
            var result = [[T]]()
            accessQueue.sync { result = _objects }
            return result
        }
        set {
            let operation = BlockOperation()
            operation.addExecutionBlock { [weak self, unowned operation] in
                guard let strongSelf = self, !operation.isCancelled else { return }
                let oldValue = strongSelf.objects
                strongSelf.accessQueue.sync(flags: .barrier) {
                    strongSelf._objects = newValue
                }
                strongSelf.objectsDidChange(oldValue: oldValue)
            }
            changeQueue.addOperation(operation)
        }
    }
    
    func cancelPreviousChanges() {
        changeQueue.cancelAllOperations()
    }
    
    // MARK: - Collection
    
    subscript(indexPath: IndexPath) -> T {
        var result: T!
        accessQueue.sync {
            result = _objects[indexPath.section][indexPath.row]
        }
        return result
    }
    
    var startIndex: IndexPath {
        return IndexPath(row: 0, section: 0)
    }
    
    var endIndex: IndexPath {
        var indexPath = IndexPath(row: 0, section: 0)
        accessQueue.sync {
            guard _objects.count > 0 else { return }
            let section = _objects.count - 1
            indexPath = IndexPath(row: _objects[section].count, section: section)
        }
        return indexPath
    }
    
    func index(after i: IndexPath) -> IndexPath {
        var indexPath = IndexPath(row: i.row + 1, section: i.section)
        accessQueue.sync {
            if i.row + 1 < _objects[i.section].count { return }
            var nextSection = i.section + 1
            while nextSection < _objects.count {
                let nextIsEmpty = _objects[nextSection].isEmpty
                if nextSection + 1 == _objects.count, nextIsEmpty {}
                else if nextIsEmpty {
                    nextSection += 1
                    continue
                }
                indexPath = IndexPath(row: 0, section: nextSection)
                return
            }
        }
        return indexPath
    }
    
    var count: Int {
        return objects.count
    }
    
    // MARK: - Sequence
    
    func makeIterator() -> AnyIterator<T> {
        var iterator: IndexingIterator<[T]>!
        accessQueue.sync {
            iterator = _objects.flatMap { $0 }.makeIterator()
        }
        return AnyIterator { [weak self] in
            var next: T?
            self?.accessQueue.sync { next = iterator.next() }
            return next
        }
    }
    
    // MARK: - ObjectChange
    
    enum ObjectChange {
        case begin
        case added(indexPath: IndexPath)
        case moved(oldIndexPath: IndexPath, newIndexPath: IndexPath)
        case deleted(indexPath: IndexPath)
        case sectionsAdded(indexSet: IndexSet)
        case sectionsDeleted(indexSet: IndexSet)
        case end
        case new
    }
    
    // MARK: - Change handler
    
    private lazy var changeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private func objectsDidChange(oldValue: [[T]]) {
        guard delegate != nil else { return }
        if oldValue.isEmpty || objects.isEmpty {
            setupChanges([.new])
            return
        }
        var changes = [ObjectChange.begin]
        var changedSections = 0..<0
        if oldValue.count < objects.count {
            changedSections = oldValue.count..<objects.count
            let indexSet = IndexSet(integersIn: changedSections)
            changes.append(.sectionsAdded(indexSet: indexSet))
        } else if objects.count < oldValue.count {
            changedSections = objects.count..<oldValue.count
            let indexSet = IndexSet(integersIn: changedSections)
            changes.append(.sectionsDeleted(indexSet: indexSet))
        }
        var newEnumareted = enumarate(objects: objects)
        loop: for (oldIndexPath, oldObject) in enumarate(objects: oldValue) {
            for (i, newObject) in newEnumareted.enumerated() where newObject.object == oldObject  {
                if newObject.indexPath != oldIndexPath {
                    if !changedSections.contains(newObject.indexPath.section),
                        !changedSections.contains(oldIndexPath.section) {
                        changes.append(.moved(oldIndexPath: oldIndexPath,
                                              newIndexPath: newObject.indexPath))
                    } else if changedSections.contains(oldIndexPath.section) {
                        changes.append(.added(indexPath: newObject.indexPath))
                    } else {
                        changes.append(.deleted(indexPath: oldIndexPath))
                    }
                }
                newEnumareted.remove(at: i)
                continue loop
            }
            if !changedSections.contains(oldIndexPath.section) {
                changes.append(.deleted(indexPath: oldIndexPath))
            }
        }
        for (indexPath, _) in newEnumareted {
            guard !changedSections.contains(indexPath.section) else { continue }
            changes.append(.added(indexPath: indexPath))
        }
        changes.append(.end)
        setupChanges(changes)
    }
    
    private func enumarate(objects: [[T]]) -> [(indexPath: IndexPath, object: T)] {
        return objects.enumerated().flatMap { (sectionIndex, sectionArray) in
            sectionArray.enumerated().map { (row, object) in
                (IndexPath(row: row, section: sectionIndex), object)
            }
        }
    }
    
    private func setupChanges(_ changes: [ObjectChange]) {
        guard let delegate = delegate else { return }
        DispatchQueue.main.sync {
            for change in changes {
                delegate.objectAtIndex(change, manager: self)
            }
        }
    }
    
}
