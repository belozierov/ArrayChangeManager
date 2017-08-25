//
//  ArrayChangeManager.swift
//  
//
//  Created by Beloizerov on 25.08.17.
//
//

protocol ArrayChangeManagerDelegate: class {
    
    associatedtype Object: Comparable
    typealias Manager = ArrayChangeManager<Self>
    
    func objectAtIndex(_ change: Manager.ObjectChange, manager: Manager)
    
}

class ArrayChangeManager<D: ArrayChangeManagerDelegate>: Collection {
    
    weak var delegate: D?
    typealias DataType = D.Object
    
    // MARK: - Objects
    
    private let accessQueue = DispatchQueue(label: "accessQueue", attributes: .concurrent)
    private var _objects = [DataType]()
    
    var objects: [DataType] {
        get {
            var result = [DataType]()
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
    
    subscript(index: Int) -> DataType { return objects[index] }
    var startIndex: Int { return 0 }
    var endIndex: Int { return objects.count }
    func index(after i: Int) -> Int { return i + 1 }
    
    // MARK: - ObjectChange
    
    enum ObjectChange {
        case begin
        case added(position: Int)
        case moved(oldPosition: Int, newPosition: Int)
        case deleted(position: Int)
        case end
        case new
    }
    
    // MARK: - Change handler
    
    private lazy var changeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private func objectsDidChange(oldValue: [DataType]) {
        guard delegate != nil, oldValue != objects else { return }
        if oldValue.isEmpty || objects.isEmpty {
            setupChanges([.new])
            return
        }
        var changes = [ObjectChange.begin]
        var newEnumareted = objects.enumerated().map { (position: $0.offset, object: $0.element) }
        loop: for (position, object) in oldValue.enumerated() {
            for (i, newObject) in newEnumareted.enumerated() where newObject.object == object  {
                if newObject.position != position {
                    changes.append(.moved(oldPosition: position, newPosition: newObject.position))
                }
                newEnumareted.remove(at: i)
                continue loop
            }
            changes.append(.deleted(position: position))
        }
        for (position, _) in newEnumareted {
            changes.append(.added(position: position))
        }
        changes.append(.end)
        setupChanges(changes)
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
