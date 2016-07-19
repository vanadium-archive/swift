// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit

enum Category: Int {
  case NearbyContacts
  case Nearby
  case Contacts
  static let allRawValues = [NearbyContacts.rawValue, Nearby.rawValue, Contacts.rawValue]
}

class InviteViewController: UITableViewController {
  var searchController: UISearchController!
  let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
  let personCellId = "personCellId"
  let sendEmailCell = "sendEmailCellId"
  var shouldDismiss = false
  var people: [[Person]] = [[], [], []]
  var searchResultsFound = false
  var searchResults: [[Person]] = [[], [], []]
  let sectionNames: [Category: String] = [
      .NearbyContacts: "Nearby Contacts",
      .Nearby: "Nearby",
      .Contacts: "Contacts",
  ]

  override func viewDidLoad() {
    super.viewDidLoad()
    initSearchController()
//    createFakeData()
//    tableView.reloadData()
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

//  func createFakeData() {
//    // TODO(azinman): Remove.
//    people.insert([
//      Person(name: "Lady Rainicorn", imageName: "profilePhoto"),
//      Person(name: "Princess Bubblegum", imageName: "profilePhoto"),
//      Person(name: "Ice King", imageName: "profilePhoto")
//      ],
//      atIndex: Category.NearbyContacts.rawValue
//    )
//
//    people.insert([
//      Person(name: "Gunter", imageName: "profilePhoto"),
//      Person(name: "dayang@google.com", imageName: "profilePhoto"),
//      Person(name: "Tom", imageName: "profilePhoto"),
//      ],
//      atIndex: Category.Nearby.rawValue
//    )
//
//    people.insert([
//      Person(name: "Lady Rainicorn", imageName: "profilePhoto"),
//      ],
//      atIndex: Category.Contacts.rawValue
//    )
//  }

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
      cell.person = searchResults[indexPath.section][indexPath.row]
    } else {
      // Not searching, show entire list.
      cell.person = people[indexPath.section][indexPath.row]
    }
    cell.updateView()
    return cell
  }

  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    // No-op if can't create a person from index path.
    if let personToInvite = personToInvite(indexPath) {
      invitePerson(personToInvite)
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

  func invitePerson(person: Person) {
    NSLog("Inviting \(person)")
    // TODO(azinman): fill in.
  }

  func personToInvite(indexPath: NSIndexPath) -> Person? {
    // Determine if we entered an email or not. If email, validate email and construct a Person obj.
    var personToInvite: Person?
    if let text = searchController.searchBar.text where searchController.active && !searchResultsFound {
      let validEmail = NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluateWithObject(text)
      if validEmail {
        // Create new person with this email.
        personToInvite = Person(name: "", imageRef: "", email: text)
      } else {
        // Invalid email, show alert.
        let alert = UIAlertController(title: "Invalid email",
          message: "Please enter a valid email",
          preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
        navigationController?.presentViewController(alert, animated: true, completion: nil)
      }
    } else if people.indices.contains(indexPath.section) &&
    people[indexPath.row].indices.contains(indexPath.row) {
      // We're inviting an existing Person.
      personToInvite = people[indexPath.section][indexPath.row]
    }
    return personToInvite
  }

  func didDismissSearchController(searchController: UISearchController) {
    // If we were searching when we selected a person, we need to wait for its dismiss animation
    // to finish before popping the view.
    if shouldDismiss {
      navigationController?.popViewControllerAnimated(true)
    }
  }
}

// Filters people to match the text user searched for.
extension InviteViewController: UISearchControllerDelegate, UISearchResultsUpdating {
  func updateSearchResultsForSearchController(searchController: UISearchController) {
    // Start with all people, then filter.
    searchResults = people

    if let searchText = searchController.searchBar.text where searchText.characters.count > 0 {
      for category in Category.allRawValues {
        searchResults[category] = searchResults[category].filter { person -> Bool in
          return person.name.rangeOfString(searchText,
            options: .CaseInsensitiveSearch,
            range: person.name.startIndex ..< person.name.endIndex,
            locale: nil) != nil
        }
      }
    }

    searchResultsFound = searchResults.flatten().count > 0
    tableView.reloadData()
  }
}

// Displays a person with name and their profile photo.
class PersonCell: UITableViewCell {
  @IBOutlet weak var photoImageView: UIImageView!
  @IBOutlet weak var nameLabel: UILabel!
  var person: Person?

  func updateView() {
    nameLabel.text = person?.name
//    if let imageName = person?.imageName {
//      photoImageView.image = UIImage(named: imageName)
//    }
  }
}

// Display a cell that shows the email the invite will be sent to.
class SendEmailCell: UITableViewCell {
  @IBOutlet weak var emailLabel: UILabel!
}