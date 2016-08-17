// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Contacts
import ContactsUI
import Syncbase
import UIKit

enum Category: Int {
  case NearbyContacts
  case Nearby
  case Contacts
  static let allRawValues = [NearbyContacts.rawValue, Nearby.rawValue, Contacts.rawValue]
}

class InviteViewController: UITableViewController {
  // Represents the search bar.
  var searchController: UISearchController!
  // All known people -- this is the model that the tableview loads from.
  var people: [[Contact]] = [[], [], []]
  // Allows us to look up address book contacts we might discover via BLE/mDNS.
  var contactsByLowercaseEmail: [String: Contact] = [:]
  var contactsByLowercaseEmailMu = NSLock()
  // True if the search controller's text matches any existing contacts.
  var searchResultsFound = false
  // All matching people for a given search -- this is the model the tableview loads from.
  var searchResults: [[Contact]] = [[], [], []]
  // True if contacts were able to be loaded from the iOS Address Book.
  var didLoadContacts = false
  // The TodoList we are inviting users to.
  var todoList: TodoList!

  // Regex used to know when a search represents an email address.
  let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
  // The cell that displays people's names or emails.
  let personCellId = "personCellId"
  // The cell that represents sending an invite directly to an email address.
  let sendEmailCell = "sendEmailCellId"
  // The names of each section of the table view.
  var sectionNames: [Category: String] = [
      .NearbyContacts: "Nearby Contacts",
      .Nearby: "Nearby",
      .Contacts: "Contacts",
  ]
  // Set to true if the user clicked on a name to invite while the seearch controller was active.
  // The invite logic first waits for the search controller to turn inactive before the view
  // controller is dismissed. This variable keeps track for the didDismissSearchController callback
  // to know if it should dismiss the VC or not.
  var shouldDismiss = false

  override func viewDidLoad() {
    super.viewDidLoad()
    guard todoList.collection != nil else {
      print("Missing collection from todo list \(todoList)")
      // Pop view since we can't invite a user. This must be done outside of the viewDidLoad.
      dispatch_async(dispatch_get_main_queue()) {
        self.dismissViewControllerAnimated(true) { }
      }
      return
    }
    initSearchController()
    loadContacts() {
      do {
        try Syncbase.startScanForUsersInNeighborhood(
          ScanNeighborhoodForUsersHandler(onFound: self.onFound, onLost: self.onLost))
      } catch {
        print("Unable to scan for other users: \(error)")
      }
    }
  }

  override func viewWillDisappear(animated: Bool) {
    Syncbase.stopAllScansForUsersInNeighborhood()
  }

  func initSearchController() {
    // Cannot be done in IB yet.
    searchController = UISearchController(searchResultsController: nil)
    searchController.delegate = self
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    searchController.searchBar.sizeToFit()
    tableView.tableHeaderView = searchController.searchBar
    definesPresentationContext = true
  }

  // MARK: Address Book contacts

  func loadContacts(doneCallback: Void -> Void) {
    CNContactStore().requestAccessForEntityType(.Contacts) { (granted, error) in
      guard granted && error == nil else {
        print("Contants not able to load: granted=\(granted) error=\(error)")
        dispatch_async(dispatch_get_main_queue()) {
          self.disableContacts()
          doneCallback()
        }
        return
      }
      let request = CNContactFetchRequest(keysToFetch: Contact.keysToFetch)
      var results: [Contact] = []
      do {
        self.contactsByLowercaseEmailMu.lock()
        defer { self.contactsByLowercaseEmailMu.unlock() }
        // This is a bit slow loading everything at once. In a real app you want to take a more
        // advanced strategy, perhaps updating the UI in batches or some other methodology.
        try CNContactStore().enumerateContactsWithFetchRequest(request) { (cncontact, stop) in
          let contact = Contact(contact: cncontact)
          results.append(contact)
          if let emails = contact.emails {
            for email in emails {
              // The email was lowercased in the Contact class's init.
              self.contactsByLowercaseEmail[email] = contact
            }
          }
        }
        dispatch_async(dispatch_get_main_queue()) {
          self.didLoadContacts = true
          self.people[Category.Contacts.rawValue] = results
          self.tableView.reloadData()
          doneCallback()
        }
      } catch {
        print("Unable to fetch contacts: \(error)")
        dispatch_async(dispatch_get_main_queue()) {
          self.disableContacts()
          doneCallback()
        }
      }
    }
  }

  /// disableContacts is used when the user has not granted authorization to contacts or some other
  /// error has occured loading contacts. Must be called from main.
  func disableContacts() {
    didLoadContacts = false
    sectionNames[.Contacts] = nil
    sectionNames[.NearbyContacts] = nil
    people = [people[Category.Nearby.rawValue]]
    searchResults = [searchResults[Category.Nearby.rawValue]]
    tableView.reloadData()
  }

  // MARK: Tableview delegates

  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    if searchController.active && !searchResultsFound {
      // We only have one section in the case of the send email cell.
      return 1
    }
    return sectionNames.count
  }

  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if searchController.active {
      if searchResultsFound {
        return searchResults[section].count
      } else {
        // We only have one row in the case of the send email cell.
        return 1
      }
    }
    return people[section].count
  }

  override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    view.tintColor = UIColor.whiteColor()
  }

  override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if searchController.active && !searchResultsFound {
      // Don't show a section title if we're just showing send an email cell.
      return nil
    }
    return sectionNames[Category(rawValue: section)!]
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    // In the case where we have are searching and have found no results, offer the send email cell.
    if searchController.active && !searchResultsFound {
      // This cell is a prototype inside the Main.storyboard. Cannot fail.
      let cell = tableView.dequeueReusableCellWithIdentifier(sendEmailCell, forIndexPath: indexPath) as! SendEmailCell
      cell.emailLabel.text = searchController.searchBar.text
      return cell
    }

    // This cell is a prototype inside the Main.storyboard. Cannot fail.
    let cell = self.tableView.dequeueReusableCellWithIdentifier(personCellId, forIndexPath: indexPath) as! PersonCell
    if searchController.active {
      // Show search results.
      cell.contact = searchResults[indexPath.section][indexPath.row]
    } else {
      // Not searching, show entire list.
      cell.contact = people[indexPath.section][indexPath.row]
    }
    cell.updateView()
    return cell
  }

  override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
    if searchController.active && !searchResultsFound {
      return SendEmailCell.height
    }
    return PersonCell.height
  }

  // MARK: Inviting

  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    // No-op if can't create a person from index path.
    if let contact = contactAtIndexPath(indexPath) {
      do {
        try inviteContact(contact)
      } catch {
        print("Unable to invite \(contact): \(error)")
        let ac = UIAlertController(
          title: "Oops!",
          message: "Unable to send invite. Try again.",
          preferredStyle: .Alert)
        ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        presentViewController(ac, animated: true, completion: nil)
        return
      }
      // Dismiss the view.
      if searchController.active {
        // The search bar needs to close before we pop, so handle in didDismissSearch callback.
        shouldDismiss = true
        searchController.active = false
      } else {
        navigationController?.popViewControllerAnimated(true)
      }
    }
  }

  func contactAtIndexPath(indexPath: NSIndexPath) -> Contact? {
    // Determine if we entered an email or not. If email, validate email and construct a Person obj.
    var personToInvite: Contact?
    if let text = searchController.searchBar.text where searchController.active && !searchResultsFound {
      let validEmail = NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluateWithObject(text)
      if validEmail {
        // Create new person with this email.
        personToInvite = Contact(emails: [text])
      } else {
        // Invalid email, show alert.
        let alert = UIAlertController(title: "Invalid email",
          message: "Please enter a valid email",
          preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
        navigationController?.presentViewController(alert, animated: true, completion: nil)
      }
    } else if people.indices.contains(indexPath.section) &&
    people[indexPath.section].indices.contains(indexPath.row) {
      // We're inviting an existing Person.
      personToInvite = people[indexPath.section][indexPath.row]
    }
    return personToInvite
  }

  // This is called after selecting a contact if the search controller is active.
  func didDismissSearchController(searchController: UISearchController) {
    // If we were searching when we selected a person, we need to wait for its dismiss animation
    // to finish before popping the view.
    if shouldDismiss {
      navigationController?.popViewControllerAnimated(true)
    }
  }

  // inviteContact is the function responsible for actually inviting a user to the collection's
  // syncgroup.
  func inviteContact(contact: Contact) throws {
    if let user = contact.user {
      // Admin allows them to invite people to the syncgroup as well.
      try todoList.collection!.syncgroup().inviteUser(user, level: .READ_WRITE_ADMIN)
    } else if let emails = contact.emails {
      for email in emails {
        try todoList.collection!.syncgroup().inviteUser(User(alias: email), level: .READ_WRITE_ADMIN)
      }
    }
  }

  // MARK: Discovery

  func onFound(user: User) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
      // Determine if they're an existing contact.
      self.contactsByLowercaseEmailMu.lock()
      defer { self.contactsByLowercaseEmailMu.unlock() }
      var contact = Contact(user: user)
      var section = Category.Nearby.rawValue
      if let existingContact = self.contactsByLowercaseEmail[user.alias.lowercaseString] {
        contact = existingContact
        contact.user = user
        section = Category.NearbyContacts.rawValue
      }
      // If we were never able to load contacts, then they should be disabled and we only have 1
      // section.
      if !self.didLoadContacts {
        section = 0
      }
      dispatch_async(dispatch_get_main_queue()) {
        self.people[section].append(contact)
        self.people[section].sortInPlace { (lhs, rhs) -> Bool in
          return lhs.description.compare(rhs.description) == NSComparisonResult.OrderedAscending
        }
        self.tableView.reloadSections(NSIndexSet(index: section), withRowAnimation: .Automatic)
      }
    }
  }

  func onLost(user: User) {
    for section in nearbySections {
      if let idx = people[section].indexOf({ $0.user == user }) {
        people[section].removeAtIndex(idx)
        tableView.reloadSections(NSIndexSet(index: section), withRowAnimation: .Automatic)
        break
      }
    }
  }

  var nearbySections: [Int] {
    if didLoadContacts {
      return [Category.NearbyContacts.rawValue, Category.Nearby.rawValue]
    }
    return [0]
  }
}

// MARK: Search

// Filters people to match the text user searched for.
extension InviteViewController: UISearchControllerDelegate, UISearchResultsUpdating {
  func updateSearchResultsForSearchController(searchController: UISearchController) {
    if let searchText = searchController.searchBar.text where searchText.characters.count > 0 {
      for section in nearbySections {
        searchResults[section] = people[section].filter { contact -> Bool in
          return contact.description.rangeOfString(searchText,
            options: .CaseInsensitiveSearch,
            range: contact.description.startIndex ..< contact.description.endIndex,
            locale: nil) != nil
        }
      }
      if didLoadContacts {
        searchResults[Category.Contacts.rawValue] = []
        if let contacts = try? CNContactStore().unifiedContactsMatchingPredicate(
          CNContact.predicateForContactsMatchingName(searchText),
          keysToFetch: Contact.keysToFetch) {
            searchResults[Category.Contacts.rawValue] = contacts.map { Contact(contact: $0) }
        }
      }
    } else {
      for i in 0 ..< searchResults.count {
        searchResults[i] = []
      }
    }
    searchResultsFound = false
    for section in searchResults {
      if !section.isEmpty {
        searchResultsFound = true
        break
      }
    }
    tableView.reloadData()
  }
}

// MARK: Tableview Cells

// Displays a person with name and their profile photo.
class PersonCell: UITableViewCell {
  static let height: CGFloat = 44
  @IBOutlet weak var nameLabel: UILabel!
  var contact: Contact?

  func updateView() {
    nameLabel.text = contact?.description
  }
}

// Display a cell that shows the email the invite will be sent to.
class SendEmailCell: UITableViewCell {
  static let height: CGFloat = 74
  @IBOutlet weak var emailLabel: UILabel!
}