//
//  ViewController.swift
//  ExampleArrayChangeManager
//
//  Created by Beloizerov on 27.08.17.
//  Copyright © 2017 Home. All rights reserved.
//

import UIKit

class ViewController: UITableViewController, ArrayChangeManagerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationItem.rightBarButtonItem =
            UIBarButtonItem(title: "Update", style: .plain, target: self, action: #selector(update))
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        manager.delegate = self
    }
    
    // MARK: - BarButton
    
    func update() {
        manager.cancelPreviousChanges()
        manager.objects = (0..<random(3)).map { _ in
            (0..<random(5)).map { _ in random(10) }
        }
    }
    
    private func random(_ int: UInt32) -> Int {
        return Int(arc4random_uniform(int) + 1)
    }
    
    // MARK: - TableView delegate and dataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return manager.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return manager[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! TableViewCell
        cell.setNumber(manager[indexPath])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Section \(section)"
    }
    
    // MARK: - ArrayChangeManager
    
    private let manager = ArrayChangeManager<Int>()
    
    // MARK: - ArrayChangeManagerDelegate
    
    func objectAtIndex<Int>(_ change: ArrayChangeManager<Int>.ObjectChange, manager: ArrayChangeManager<Int>) {
        switch change {
        case .begin:
            tableView.beginUpdates()
        case .added(let indexPath):
            tableView.insertRows(at: [indexPath], with: .fade)
        case .moved(let oldIndexPath, let newIndexPath):
            tableView.moveRow(at: oldIndexPath, to: newIndexPath)
        case .deleted(let indexPath):
            tableView.deleteRows(at: [indexPath], with: .fade)
        case .sectionsAdded(let indexSet):
            tableView.insertSections(indexSet, with: .fade)
        case .sectionsDeleted(let indexSet):
            tableView.deleteSections(indexSet, with: .fade)
        case .end:
            tableView.endUpdates()
        case .new:
            tableView.reloadData()
        }
    }
    
}

