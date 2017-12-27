//
//  ViewController.swift
//  MegaController
//
//  Created by Andy Matuschak on 9/7/15.
//  Copyright © 2015 Andy Matuschak. All rights reserved.
//

import CoreData
import UIKit

class ViewController: UITableViewController, NSFetchedResultsControllerDelegate, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {

    fileprivate var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "MegaController", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            fatalError("Couldn't load database: \(error)")
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    fileprivate var taskSections: [[NSManagedObject]] = [[], [], []]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Task")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "dueDate <= %@",
                                             argumentArray: [(Calendar.current as NSCalendar).date(byAdding: .day,
                                                                                                   value: 10,
                                                                                                   to: Date(),
                                                                                                   options: NSCalendar.Options())!])
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: managedObjectContext,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController!.delegate = self
        try! fetchedResultsController!.performFetch()
        
        for task in fetchedResultsController!.fetchedObjects! as! [NSManagedObject] {
            taskSections[sectionIndexForTask(task)].append(task)
        }
        
        updateNavigationBar()
        setNeedsStatusBarAppearanceUpdate()
    }
    
    fileprivate func sectionIndexForTask(_ task: NSManagedObject) -> Int {
        let date = task.value(forKey: "dueDate") as! Date
        let numberOfDaysUntilTaskDueDate = (Calendar.current as NSCalendar).components(NSCalendar.Unit.day,
                                                                                   from: Date(),
                                                                                   to: date,
                                                                                   options: NSCalendar.Options()).day
        guard let daysTillDueDate = numberOfDaysUntilTaskDueDate else {
            return 2
        }
        switch daysTillDueDate {
        case -Int.max ... 2:
            return 0
        case 3...5:
            return 1
        default:
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        managedObjectContext.delete(taskSections[indexPath.section][indexPath.row])
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return taskSections.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Now"
        case 1:
            return "Soon"
        case 2:
            return "Upcoming"
        default:
            fatalError("Unexpected section")
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return taskSections[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let task = taskSections[indexPath.section][indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel!.text = task.value(forKey: "title") as! String?
        
        let taskDate = task.value(forKey: "dueDate") as! Date
        let now = Date()
        let calendar: NSCalendar = Calendar.current as NSCalendar
        
        var beginningOfTaskDate: NSDate? = nil
        var beginningOfToday: NSDate? = nil
        
        calendar.range(of: .day,
                       start: &beginningOfTaskDate,
                       interval: nil,
                       for: taskDate)
        calendar.range(of: .day,
                       start: &beginningOfToday,
                       interval: nil,
                       for: now)

        let numberOfCalendarDaysUntilTaskDueDate = calendar.components(NSCalendar.Unit.day,
                                                                       from: beginningOfToday! as Date,
                                                                       to: beginningOfTaskDate! as Date,
                                                                       options: NSCalendar.Options()).day

        let description: String
        if let daysUntilTaskDueDate = numberOfCalendarDaysUntilTaskDueDate {
            switch daysUntilTaskDueDate {
            case -Int.max ... -2:
                description = "\(abs(daysUntilTaskDueDate)) days ago"
            case -1:
                description = "Yesterday"
            case 0:
                description = "Today"
            case 1:
                description = "Tomorrow"
            default:
                description = "In \(daysUntilTaskDueDate) days"
            }
            
            cell.detailTextLabel!.text = description.lowercased()
        }
        return cell
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        
        updateNavigationBar()
        setNeedsStatusBarAppearanceUpdate()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		let task = anObject as! NSManagedObject
        switch type {
        case .insert:
            let insertedTaskDate = (anObject as AnyObject).value(forKey: "dueDate") as! Date
            let sectionIndex = sectionIndexForTask(task)
            let insertionIndex = taskSections[sectionIndex].index { task in
                let otherTaskDate = task.value(forKey: "dueDate") as! Date
                return insertedTaskDate.compare(otherTaskDate) == .orderedAscending
            } ?? taskSections[sectionIndex].count
            taskSections[sectionIndex].insert(task, at: insertionIndex)
            tableView.insertRows(at: [IndexPath(row: insertionIndex, section: sectionIndex)], with: .automatic)
        case .delete:
            let sectionIndex = sectionIndexForTask(task)
            let deletedTaskIndex = taskSections[sectionIndex].index(of: task)!
            taskSections[sectionIndex].remove(at: deletedTaskIndex)
            tableView.deleteRows(at: [IndexPath(row: deletedTaskIndex, section: sectionIndex)], with: .automatic)
        case .move, .update:
            fatalError("Unsupported")
        }
    }
    
    func updateNavigationBar() {
        switch fetchedResultsController!.fetchedObjects!.count {
        case 0...3:
            navigationController!.navigationBar.barTintColor = nil
            navigationController!.navigationBar.titleTextAttributes = nil
            navigationController!.navigationBar.tintColor = nil
        case 4...9:
            navigationController!.navigationBar.barTintColor = UIColor(red: 235/255, green: 156/255, blue: 77/255, alpha: 1.0)
            navigationController!.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
            navigationController!.navigationBar.tintColor = UIColor.white
        default:
            navigationController!.navigationBar.barTintColor = UIColor(red: 248/255, green: 73/255, blue: 68/255, alpha: 1.0)
            navigationController!.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
            navigationController!.navigationBar.tintColor = UIColor.white
        }
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        switch fetchedResultsController?.fetchedObjects!.count {
        case .some(0...3), .none:
            return .default
        case .some(_):
            return .lightContent
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is AddViewController {
            segue.destination.modalPresentationStyle = .overFullScreen
            segue.destination.transitioningDelegate = self
        }
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) is AddViewController {
            let addView = transitionContext.view(forKey: UITransitionContextViewKey.to)
            addView!.alpha = 0
            transitionContext.containerView.addSubview(addView!)
            UIView.animate(withDuration: 0.4, animations: {
                addView!.alpha = 1.0
            }, completion: { didComplete in
                transitionContext.completeTransition(didComplete)
            })
        } else if transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) is AddViewController {
            let addView = transitionContext.view(forKey: UITransitionContextViewKey.from)
            UIView.animate(withDuration: 0.4, animations: {
                addView!.alpha = 0.0
            }, completion: { didComplete in
                transitionContext.completeTransition(didComplete)
            })
        }
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4
    }
    
    @IBAction func unwindFromAddController(_ sender: UIStoryboardSegue) {
        let addViewController = (sender.source as! AddViewController)
        
        let newTask = NSManagedObject(entity: managedObjectContext.persistentStoreCoordinator!.managedObjectModel.entitiesByName["Task"]!, insertInto: managedObjectContext)
        newTask.setValue(addViewController.textField.text, forKey: "title")
        newTask.setValue(addViewController.datePicker.date, forKey: "dueDate")
        try! managedObjectContext.save()
    }
}
