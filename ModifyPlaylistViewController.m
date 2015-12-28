//
//  ModifyPlaylistViewController.m
//  LoopMusic
//
//  Created by Cheng Hann Gan on 12/26/15.
//  Copyright © 2015 Cheng Hann Gan. All rights reserved.
//

#import "ModifyPlaylistViewController.h"

@interface ModifyPlaylistViewController ()

@end

@implementation ModifyPlaylistViewController

- (void)viewDidLoad
{
    items = [self getTotalSongList];
    selectedItems = [presenter getSongList];
    [super viewDidLoad];
}

-(IBAction)confirmButton:(id)sender
{
    [self dismissViewControllerAnimated:true completion:nil];
    [self openDB];
    NSString* trackString = @"";
    for (NSString *item in selectedItems)
    {
        NSInteger trackIndex = [self getIntegerDB:[NSString stringWithFormat:@"SELECT id FROM Tracks WHERE name = \"%@\"", item]];
        if (trackIndex)
        {
            trackString = [trackString stringByAppendingString:[NSString stringWithFormat:@"%ld",(long)trackIndex]];
            trackString = [trackString stringByAppendingString:@","];
        }
    }
    if ([trackString length] > 0)
    {
        trackString = [trackString substringToIndex:[trackString length] - 1];
    }
    [self updateDB:[NSString stringWithFormat:@"UPDATE Playlists SET tracks = \"%@\" WHERE id = %ld", trackString, (long)playlistIndex]];
    sqlite3_close(trackData);
}

@end