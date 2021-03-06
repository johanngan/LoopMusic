//
//  SettingsViewController.m
//  LoopMusic
//
//  Created by Cheng Hann Gan on 5/24/14.
//  Copyright (c) 2014 Cheng Hann Gan. All rights reserved.
//

#import "SettingsViewController.h"
#import "SettingsStore.h"

@interface SettingsViewController ()

@end

@implementation SettingsViewController

@synthesize back, volumeAdjust, fadeText;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (void)viewDidLoad
{
    fadeText.text = [NSString stringWithFormat:@"%@", @(SettingsStore.instance.fadeSetting)];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(closeKeyboards)];
    [self.view addGestureRecognizer:tap];
}

- (void)viewWillAppear:(BOOL)animated
{
    presenter = (LoopMusicViewController*)self.presentingViewController;
    [presenter setOccupied:true];
    volumeAdjust.text = [NSString stringWithFormat:@"%@", @([presenter getVolume])];
}

- (IBAction)back:(id)sender
{
    [presenter refreshPlaySlider];  // For when the underlying audio file was changed.
    [presenter setOccupied:false];
    [self saveSettings];
    [super back:sender];
}

- (IBAction)setVolume:(id)sender
{
    if ([presenter isSongListEmpty])
    {
        [self showNoSongMessage];
        return;
    }
    if ([volumeAdjust.text doubleValue] < 0 || [volumeAdjust.text doubleValue] > 1)
    {
        volumeAdjust.text = [NSString stringWithFormat:@"%f", [presenter getVolume]];
        return;
    }
    [presenter setVolume:[volumeAdjust.text doubleValue]];
}

/*!
 * Increases the relative volume of the current track by 0.1 if possible.
 * @param sender The object that called this function.
 */
- (IBAction)addVolume:(id)sender
{
    if ([presenter isSongListEmpty])
    {
        [self showNoSongMessage];
        return;
    }
    if ([volumeAdjust.text doubleValue] >= 1)
    {
        return;
    }
    volumeAdjust.text = [NSString stringWithFormat:@"%f", [volumeAdjust.text doubleValue] + 0.1];
    [self setVolume:self];
}

/*!
 * Decreases the relative volume of the current track by 0.1 if possible.
 * @param sender The object that called this function.
 */
- (IBAction)subtractVolume:(id)sender
{
    if ([presenter isSongListEmpty])
    {
        [self showNoSongMessage];
        return;
    }
    if ([volumeAdjust.text doubleValue] <= 0)
    {
        return;
    }
    volumeAdjust.text = [NSString stringWithFormat:@"%f", [volumeAdjust.text doubleValue] - 0.1];
    [self setVolume:self];
}

/*!
 * Updates the current track's entry in the database.
 * @param field1 The field to update.
 * @param newTime The new value to insert in the field.
 * @return The result code of the database query.
 */
- (NSInteger)sqliteUpdate:(NSString*)field1 newTime:(double)newTime
{
    [self openDB];
    /// The result code of the database query.
    NSInteger result = 0;
    /// The database query to update with.
    NSString *querySQL = [NSString stringWithFormat:@"UPDATE Tracks SET %@ = %f WHERE name = \"%@\"", field1, newTime, settingsSongString];
    result = [self updateDBResult:querySQL];
    if (result != 101)
    {
        [self showErrorMessage:[NSString stringWithFormat:@"Failed to update database (%li). Restart the app.", (long)result]];
    }
    sqlite3_close(trackData);
    return result;
}

- (IBAction)setFade:(id)sender
{
    if ([fadeText.text doubleValue] >= 0)
    {
        SettingsStore.instance.fadeSetting = [fadeText.text doubleValue];
        [presenter updateVolumeDec];
    }
    else
    {
        fadeText.text = @"Invalid";
    }
}

/*!
 * Closes any open keyboards.
 */
- (void)closeKeyboards
{
    [volumeAdjust resignFirstResponder];
    [fadeText resignFirstResponder];
}

/*!
 * Prompts the user to add tracks to the app from iTunes.
 * @param sender The object that called this function.
 */
- (IBAction)addSong:(id)sender
{
    addingSong = true;
    /// The picker to use when adding tracks.
    MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    
    [picker setDelegate: self];
    [picker setAllowsPickingMultipleItems: YES];
    picker.prompt = @"Add tracks";
    
    [self presentViewController:picker
                       animated:true
                     completion:nil];
}

/*!
 * Prompts the user to rename the current track.
 * @param sender The object that called this function.
 */
- (IBAction)renameSong:(id)sender
{
    if ([presenter isSongListEmpty])
    {
        [self showNoSongMessage];
        return;
    }
    alertIndex = 0;
    [self showTwoButtonMessageInput:@"Rename Track" :@"Enter a new name for the track." :@"Rename" :[presenter getSongName]];
}

/*!
 * Sent to the delegate when the user clicks a button on an alert view.
 * @discussion The receiver is automatically dismissed after this method is invoked.
 * @param alertView The alert view containing the button.
 * @param buttonIndex The index of the button that was clicked. The button indices start at 0.
 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        return;
    }
    /// The new name of the playlist or song.
    NSString* newName = [[alertView textFieldAtIndex:0] text];
    if ([newName isEqualToString:@""])
    {
        [self showErrorMessage:@"The name cannot be blank."];
        return;
    }
    if (alertIndex == 0)
    {
        if (![newName isEqualToString:[presenter getSongName]])
        {
            [self openDB];
            [self prepareQuery:[NSString stringWithFormat:@"SELECT name FROM Tracks WHERE name=\"%@\"", [presenter getSongName]]];
            if (sqlite3_step(statement) == SQLITE_ROW)
            {
                [self updateDB:[NSString stringWithFormat:@"UPDATE Tracks SET name = \"%@\" WHERE name = \"%@\"", newName, [presenter getSongName]]];
                [presenter setNewSongName:newName];
            }
            sqlite3_finalize(statement);
            sqlite3_close(trackData);
        }
    }
    else if (alertIndex == 1)
    {
        // Rename playlist.
        if (SettingsStore.instance.playlistIndex && ![newName isEqualToString:[presenter getPlaylistName]])
        {
            [self openDB];
            [self prepareQuery:[NSString stringWithFormat:@"SELECT id FROM PlaylistNames WHERE name=\"%@\"", newName]];
            if (sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_int(statement, 0) != SettingsStore.instance.playlistIndex)
            {
                [self showErrorMessage:@"Name is already used."];
            }
            else
            {
                [self updateDB:[NSString stringWithFormat:@"UPDATE PlaylistNames SET name = \"%@\" WHERE id = \"%ld\"", newName, (long)SettingsStore.instance.playlistIndex]];
            }
            sqlite3_finalize(statement);
            sqlite3_close(trackData);
            [presenter updatePlaylistName:newName];
        }
    }
    else if (alertIndex == 2)
    {
        // Add playlist.
        [self openDB];
        [self prepareQuery:[NSString stringWithFormat:@"SELECT id FROM PlaylistNames WHERE name=\"%@\"", newName]];
        if (sqlite3_step(statement) == SQLITE_ROW)
        {
            NSLog(@"%d", sqlite3_column_int(statement, 0));
            [self showErrorMessage:@"Name is already used."];
        }
        else
        {
            [self updateDB:[NSString stringWithFormat:@"INSERT INTO PlaylistNames (name) VALUES (\"%@\")", newName]];
            sqlite3_finalize(statement);
            [self prepareQuery:[NSString stringWithFormat:@"SELECT id FROM PlaylistNames WHERE name=\"%@\"", newName]];
            if (sqlite3_step(statement) == SQLITE_ROW)
            {
                SettingsStore.instance.playlistIndex = sqlite3_column_int(statement, 0);
            }
        }
        sqlite3_finalize(statement);
        sqlite3_close(trackData);
        [presenter updatePlaylistSongs];
        [presenter updatePlaylistName];
    }
}

/*!
 * Prompts the user to replace the current track with one from the device's iTunes library.
 * @param sender The object that called this method.
 */
- (IBAction)replaceSong:(id)sender
{
    if ([presenter isSongListEmpty])
    {
        [self showNoSongMessage];
        return;
    }
    addingSong = false;
    /// The picker to use to replace the current track.
    MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    
    [picker setDelegate: self];
    [picker setAllowsPickingMultipleItems: NO];
    picker.prompt = @"Replace track";
    
    [self presentViewController:picker
                       animated:true
                     completion:nil];
}

- (void)mediaPicker:(MPMediaPickerController *) mediaPicker didPickMediaItems:(MPMediaItemCollection *)collection
{
    [self dismissViewControllerAnimated:true
                             completion:nil];
    [self openDB];
    if (addingSong)
    {
        for (MPMediaItem *item in collection.items)
        {
            /// The name of the track in the current iteration.
            NSString *itemName = [item valueForProperty:MPMediaItemPropertyTitle];
            /// The resource URL of the track in the current iteration.
            NSURL *itemURL = [item valueForProperty:MPMediaItemPropertyAssetURL];
            [self prepareQuery:[NSString stringWithFormat:@"SELECT url FROM Tracks WHERE name=\"%@\"", itemName]];
            if (sqlite3_step(statement) == SQLITE_ROW)
            {
                [self updateDB:[NSString stringWithFormat:@"UPDATE Tracks SET url = \"%@\" WHERE name = \"%@\"", itemURL.absoluteString, itemName]];
            }
            else
            {
                sqlite3_finalize(statement);
                [self prepareQuery:[NSString stringWithFormat:@"SELECT name FROM Tracks WHERE url=\"%@\"", itemURL]];
                if (sqlite3_step(statement) != SQLITE_ROW)
                {
                    [self updateDB:[NSString stringWithFormat:@"INSERT INTO Tracks (name, loopstart, loopend, volume, enabled, url) VALUES (\"%@\", 0, 0, 0.3, 1, \"%@\")", itemName, itemURL.absoluteString]];
                    [presenter incrementTotalSongs];
                }
            }
            sqlite3_finalize(statement);

//            // This should be able to replace everything within the for loop, but hasn't been tested.
//            [self addSongToDB:itemName :itemURL];
//            [presenter incrementTotalSongs];
        }
    }
    else
    {
        for (MPMediaItem *item in collection.items)
        {
            /// The resource URL of the track in the current iteration.
            NSURL *itemURL = [item valueForProperty:MPMediaItemPropertyAssetURL];
            [self prepareQuery:[NSString stringWithFormat:@"SELECT url FROM Tracks WHERE name=\"%@\"", [presenter getSongName]]];
            if (sqlite3_step(statement) == SQLITE_ROW)
            {
                [self updateDB:[NSString stringWithFormat:@"UPDATE Tracks SET url = \"%@\" WHERE name = \"%@\"", itemURL.absoluteString, [presenter getSongName]]];
                [presenter setAudioPlayer:itemURL];
            }
            sqlite3_finalize(statement);
            break;
        }
    }
    [self closeDB];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker
{
    [self dismissViewControllerAnimated:true
                             completion:nil];
}

/*!
 * Navigates to the track deletion screen.
 * @param sender The object that called this function.
 */
- (IBAction)deleteSong:(id)sender
{
    if ([presenter isSongListEmpty])
    {
        [self showNoSongMessage];
    }
    else
    {
        [self changeScreen:@"delete"];
    }
}


- (IBAction)choosePlaylist:(id)sender
{
    [self changeScreen:@"choosePlaylist"];
}

- (IBAction)modifyPlaylist:(id)sender
{
    if (!SettingsStore.instance.playlistIndex)
    {
        [self showErrorMessage:@"The \"All tracks\" playlist can't be modified."];
    }
    else if ([presenter isSongListEmpty])
    {
        [self showNoSongMessage];
    }
    else
    {
        [self changeScreen:@"modifyPlaylist"];
    }
}

- (IBAction)newPlaylist:(id)sender
{
    alertIndex = 2;
    [self showTwoButtonMessageInput:@"New Playlist" :@"Enter the name of the playlist." :@"Add" :nil];
}

- (IBAction)renamePlaylist:(id)sender
{
    if (SettingsStore.instance.playlistIndex)
    {
        alertIndex = 1;
        [self showTwoButtonMessageInput:@"Rename Playlist" :@"Enter a new name for the playlist." :@"Rename" :[presenter getPlaylistName]];
    }
    else
    {
        [self showErrorMessage:@"The \"All tracks\" playlist can't be modified."];
    }
}

- (IBAction)deletePlaylist:(id)sender
{
    [self changeScreen:@"deletePlaylist"];
}

- (IBAction)openShuffleSettings:(id)sender
{
    [self changeScreen:@"shuffleSettings"];
}

- (float)getVolumeSliderValue
{
    return [presenter getVolumeSliderValue];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
