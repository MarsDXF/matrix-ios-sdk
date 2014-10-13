/*
 Copyright 2014 OpenMarket Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "HomeViewController.h"

#import "MatrixHandler.h"
#import "AppDelegate.h"

@interface HomeViewController ()
@property (weak, nonatomic) IBOutlet UILabel *roomCreationLabel;
@property (weak, nonatomic) IBOutlet UILabel *roomNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *roomAliasLabel;
@property (weak, nonatomic) IBOutlet UILabel *participantsLabel;
@property (weak, nonatomic) IBOutlet UITextField *roomNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *roomAliasTextField;
@property (weak, nonatomic) IBOutlet UITextField *participantsTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *roomVisibilityControl;
@property (weak, nonatomic) IBOutlet UIButton *createRoomBtn;
- (IBAction)onButtonPressed:(id)sender;

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    _roomCreationLabel.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    _createRoomBtn.enabled = NO;
    _createRoomBtn.alpha = 0.5;
    
    // Init
    _publicRooms = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Ensure to display room creation section
    [self.tableView scrollRectToVisible:_roomCreationLabel.frame animated:NO];
    
    if ([[MatrixHandler sharedHandler] isLogged]) {
        // Update alias placeholder
        _roomAliasTextField.placeholder = [NSString stringWithFormat:@"(e.g. #foo:%@)", [[MatrixHandler sharedHandler] homeServer]];
        // Refresh listed public rooms
        [self refreshPublicRooms];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTextFieldChange:) name:UITextFieldTextDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_publicRooms){
        return _publicRooms.count;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *sectionHeader = [[UILabel alloc] initWithFrame:[tableView rectForHeaderInSection:section]];
    sectionHeader.font = [UIFont boldSystemFontOfSize:16];
    sectionHeader.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    
    if (_publicRooms) {
        NSString *homeserver = [[MatrixHandler sharedHandler] homeServerURL];
        if (homeserver.length) {
            sectionHeader.text = [NSString stringWithFormat:@" Public Rooms (at %@):", homeserver];
        } else {
            sectionHeader.text = @" Public Rooms:";
        }
    } else {
        sectionHeader.text = @" No Public Rooms";
    }
    
    return sectionHeader;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [_publicRoomsTable dequeueReusableCellWithIdentifier:@"PublicRoomCell" forIndexPath:indexPath];
    
    MXPublicRoom *publicRoom = [_publicRooms objectAtIndex:indexPath.row];
    cell.textLabel.text = [publicRoom displayname];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Join the selected room
    MXPublicRoom *publicRoom = [_publicRooms objectAtIndex:indexPath.row];
    [[[MatrixHandler sharedHandler] mxSession] join:publicRoom.room_id success:^{
        // Show joined room
        [[AppDelegate theDelegate].masterTabBarController showRoomDetails:publicRoom.room_id];
    } failure:^(NSError *error) {
        NSLog(@"Failed to join public room (%@) failed: %@", publicRoom.displayname, error);
        //Alert user
        [[AppDelegate theDelegate] showErrorAsAlert:error];
    }];
    
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Internals

- (void)refreshPublicRooms {
    // Retrieve public rooms
    [[[MatrixHandler sharedHandler] mxHomeServer] publicRooms:^(NSArray *rooms){
        _publicRooms = rooms;
        [_publicRoomsTable reloadData];
    }
                                                    failure:^(NSError *error){
                                                        NSLog(@"GET public rooms failed: %@", error);
                                                        //Alert user
                                                        [[AppDelegate theDelegate] showErrorAsAlert:error];
                                                    }];
    
}

- (void)dismissKeyboard {
    // Hide the keyboard
    [_roomNameTextField resignFirstResponder];
    [_roomAliasTextField resignFirstResponder];
    [_participantsTextField resignFirstResponder];
}

- (NSString*)alias {
    // Extract alias name from alias text field
    NSString *alias = _roomAliasTextField.text;
    if (alias.length > 1) {
        // Remove '#' character
        alias = [alias substringFromIndex:1];
        // Remove homeserver
        NSString *suffix = [NSString stringWithFormat:@":%@",[[MatrixHandler sharedHandler] homeServer]];
        NSRange range = [alias rangeOfString:suffix];
        alias = [alias stringByReplacingCharactersInRange:range withString:@""];
    }
    
    if (! alias.length) {
        alias = nil;
    }
    
    return alias;
}

- (NSArray*)participantsList {
    NSMutableArray *participants = [NSMutableArray array];
    
    if (_participantsTextField.text.length) {
        NSArray *components = [_participantsTextField.text componentsSeparatedByString:@";"];
        
        for (NSString *component in components) {
            // Remove white space from both ends
            NSString *user = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (user.length > 1 && [user hasPrefix:@"@"]) {
                [participants addObject:user];
            }
        }
    }
    
    if (participants.count == 0) {
        participants = nil;
    }
    
    return participants;
}

#pragma mark - UITextField delegate

- (void)onTextFieldChange:(NSNotification *)notif {
    NSString *roomName = _roomNameTextField.text;
    NSString *roomAlias = _roomAliasTextField.text;
    NSString *participants = _participantsTextField.text;
    
    if (roomName.length || roomAlias.length || participants.length) {
        _createRoomBtn.enabled = YES;
        _createRoomBtn.alpha = 1;
    } else {
        _createRoomBtn.enabled = NO;
        _createRoomBtn.alpha = 0.5;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == _roomAliasTextField) {
        textField.text = self.alias;
        textField.placeholder = @"foo";
    } else if (textField == _participantsTextField) {
        if (textField.text.length == 0) {
            textField.text = @"@";
        }
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == _roomAliasTextField) {
        // Compute the new phone number with this string change
        NSString * alias = textField.text;
        if (alias.length) {
            // add homeserver as suffix
            textField.text = [NSString stringWithFormat:@"#%@:%@", alias, [[MatrixHandler sharedHandler] homeServer]];
        }
        
        textField.placeholder = [NSString stringWithFormat:@"(e.g. #foo:%@)", [[MatrixHandler sharedHandler] homeServer]];
    } else if (textField == _participantsTextField) {
        NSArray *participants = self.participantsList;
        textField.text = [participants componentsJoinedByString:@"; "];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // Auto complete participant IDs
    if (textField == _participantsTextField) {
        // Auto completion is active only when the change concerns the end of the current string
        if (range.location == textField.text.length) {
            NSString *participants = [textField.text stringByReplacingCharactersInRange:range withString:string];
            
            if ([string isEqualToString:@";"]) {
                // Add '@' character
                participants = [participants stringByAppendingString:@" @"];
            } else if ([string isEqualToString:@":"]) {
                // Add homeserver
                participants = [participants stringByAppendingString:[[MatrixHandler sharedHandler] homeServer]];
            }
            
            textField.text = participants;
            
            // Update Create button status
            [self onTextFieldChange:nil];
            return NO;
        }
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField*) textField {
    // "Done" key has been pressed
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - 

- (IBAction)onButtonPressed:(id)sender {
    [self dismissKeyboard];
    
    if (sender == _createRoomBtn) {
        NSString *roomName = _roomNameTextField.text;
        if (! roomName.length) {
            roomName = nil;
        }
        // Create new room
        [[[MatrixHandler sharedHandler] mxSession]
         createRoom:roomName
         visibility:(_roomVisibilityControl.selectedSegmentIndex == 0) ? kMXRoomVisibilityPublic : kMXRoomVisibilityPrivate
         room_alias_name:self.alias
         topic:nil
         invite:self.participantsList
         success:^(MXCreateRoomResponse *response) {
             // Open created room
             [[AppDelegate theDelegate].masterTabBarController showRoomDetails:response.room_id];
         } failure:^(NSError *error) {
             NSLog(@"Create room (%@ %@ %@ (%d)) failed: %@", _roomNameTextField.text, self.alias, self.participantsList, _roomVisibilityControl.selectedSegmentIndex, error);
             //Alert user
             [[AppDelegate theDelegate] showErrorAsAlert:error];
         }];
    }
}

@end
