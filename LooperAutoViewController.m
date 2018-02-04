//
//  LooperAutoViewController.m
//  LoopMusic
//
//  Created by Johann Gan on 1/21/18.
//  Copyright © 2018 Cheng Hann Gan. All rights reserved.
//

#import "LooperAutoViewController.h"

@implementation LooperAutoViewController

@synthesize estimateToggler, initialEstimateView, loopDurationView, loopEndpointView;

- (void)viewDidLoad
{
    // Set up subview UI interaction programmatically by their tag within the subview.
    [self setupAllUIObjects];
    
    finder = [[LoopFinderAuto alloc] init];
    
    // Default estimate flags/values, display settings
    [self disableEstimates];
    startEst = -1;
    endEst = -1;
    currentDurationRank = -1;
    currentPairRanks = [NSMutableArray new];
    originalLoopInfo = @{@"duration":@0U,
                         @"startFrame":@0U,
                         @"endFrame":@0U
                         };
    loopFinderResults = @{};
}

// Function to set up all the UI objects in subviews
- (void)setupAllUIObjects
{
    [self setupUIObject:initialEstimateView:startEstimateTextField:@selector(closeEstimates:):UIControlEventTouchDown];
    [self setupUIObject:initialEstimateView:startEstimateTextField:@selector(updateStartEstValueChanged:):UIControlEventEditingDidEnd];
    [self setupUIObject:initialEstimateView:endEstimateTextField:@selector(closeEstimates:):UIControlEventTouchDown];
    [self setupUIObject:initialEstimateView:endEstimateTextField:@selector(updateEndEstValueChanged:):UIControlEventEditingDidEnd];
    [self setupUIObject:initialEstimateView:startEstimateDecrementButton:@selector(decStartEst:):UIControlEventTouchUpInside];
    [self setupUIObject:initialEstimateView:startEstimateIncrementButton:@selector(incStartEst:):UIControlEventTouchUpInside];
    [self setupUIObject:initialEstimateView:endEstimateDecrementButton:@selector(decEndEst:):UIControlEventTouchUpInside];
    [self setupUIObject:initialEstimateView:endEstimateIncrementButton:@selector(incEndEst:):UIControlEventTouchUpInside];
    [self setupUIObject:loopDurationView:previousDurationButton:@selector(prevDuration:):UIControlEventTouchUpInside];
    [self setupUIObject:loopDurationView:nextDurationButton:@selector(nextDuration:):UIControlEventTouchUpInside];
    [self setupUIObject:loopEndpointView:previousEndpointsButton:@selector(prevEndpoints:):UIControlEventTouchUpInside];
    [self setupUIObject:loopEndpointView:nextEndpointsButton:@selector(nextEndpoints:):UIControlEventTouchUpInside];
}
// Helper function to set up a UI object in a subview programmatically
- (void)setupUIObject:(UIView *)subview :(NSInteger)tag :(SEL)actionSelector :(UIControlEvents)event
{
    [(UIButton *)[subview viewWithTag:tag] addTarget:self action:actionSelector forControlEvents:event];
}

// Helper function to update the text field of a UI object in a subview.
- (void)updateText:(UIView *)subview :(NSInteger)tag :(NSString *)text
{
    id uiObj = (id)[subview viewWithTag:tag];
    if ([uiObj respondsToSelector:@selector(setText:)])
    {
        [uiObj performSelector:@selector(setText:) withObject:text];
    }
}

// Essentially a sort of ctor (due to the way this function is called by the LooperParentViewController), but is called every time the view is re-opened, rather than just once when the view controller is instantiated.
- (void)loadPresenter:(LoopMusicViewController *)presenterPtr
{
    [super loadPresenter:presenterPtr];
    
    // If swiching from manual to auto, throw out the manual time unless the original loop time was being messed with.
    if (currentDurationRank == -1)
    {
        originalLoopInfo = [self loadCurrentLoopInfo];
        [self revertOriginalLoop:nil];  // Call outside of a button press
    }
}
// Helper function to return the current loop information from the audio player.
- (NSDictionary *)loadCurrentLoopInfo
{
    UInt32 startFrame = [presenter getAudioLoopStartFrame];
    UInt32 endFrame = [presenter getAudioLoopEndFrame];
    return @{@"duration":[NSNumber numberWithUnsignedInteger:(endFrame - startFrame)],
             @"startFrame":[NSNumber numberWithUnsignedInteger:startFrame],
             @"endFrame":[NSNumber numberWithUnsignedInteger:endFrame]
             };
}

// Helper function to convert a frame number into a time


- (IBAction)findLoop:(id)sender
{
    loopFinderResults = [finder findLoop:[presenter getAudioData]];
    long numResults = [[loopFinderResults objectForKey:@"baseDurations"] count];
    if (numResults > 0)
    {
        currentDurationRank = 0;
        for (int i = 0; i < numResults; ++i)
        {
            [currentPairRanks addObject:@0];
        }
        
        [self updateAllResults];
    }
//    NSLog(@"%@", loopFinderResults);
//    NSLog(@"Loop button pressed!");
}

- (IBAction)toggleEstimates:(id)sender
{
    useEstimates = self.estimateToggler.isOn;
    
    if (useEstimates)
    {
        [self enableEstimates];
    }
    else
    {
        [self disableEstimates];
    }
}
- (void)enableEstimates
{
    initialEstimateView.alpha = 1;
    [initialEstimateView setUserInteractionEnabled:YES];
}
- (void)disableEstimates
{
    initialEstimateView.alpha = 0.25;
    [initialEstimateView setUserInteractionEnabled:NO];
//    [(UITextField *)[initialEstimateView viewWithTag:1] resignFirstResponder];  // Start Time text
//    [(UITextField *)[initialEstimateView viewWithTag:2] resignFirstResponder];  // End Time text
    [self closeEstimates:nil];    // Call closeEstimates outside of an action by just passing nil as the sender.
}
- (IBAction)closeEstimates:(id)sender
{
    [(UITextField *)[initialEstimateView viewWithTag:startEstimateTextField] resignFirstResponder];  // Start Time text
    [(UITextField *)[initialEstimateView viewWithTag:endEstimateTextField] resignFirstResponder];  // End Time text
}
- (void)setStartEstimate:(double)est
{
    if (est < 0)
    {
        est = 0;
    }
    else if (endEst != -1 && est > endEst)
    {
        est = endEst;
    }
    else if (est > [presenter getAudioDuration])
    {
        est = [presenter getAudioDuration];
    }
    
    startEst = est;
    [self updateText:initialEstimateView :startEstimateTextField :[NSString stringWithFormat:@"%.6f", startEst]];
//    NSLog(@"startEst = %f", startEst);
}
- (void)resetStartEstimate
{
    startEst = -1;
    [self updateText:initialEstimateView :startEstimateTextField :@""];
}
- (void)setEndEstimate:(double)est
{
    if (est < 0)
    {
        est = 0;
    }
    else if (startEst != -1 && est < startEst)
    {
        est = startEst;
    }
    else if (est > [presenter getAudioDuration])
    {
        est = [presenter getAudioDuration];
    }
    
    endEst = est;
    [self updateText:initialEstimateView :endEstimateTextField :[NSString stringWithFormat:@"%.6f", endEst]];
//    NSLog(@"endEst = %f", endEst);
}
- (void)resetEndEstimate
{
    endEst = -1;
    [self updateText:initialEstimateView :endEstimateTextField :@""];
}
- (void)incStartEst:(id)sender
{
//    NSLog(@"Increment start estimate!");
    [self setStartEstimate:(startEst + 0.001)];
}
- (void)decStartEst:(id)sender
{
//    NSLog(@"Decrement start estimate!");
    [self setStartEstimate:(startEst - 0.001)];
}
- (void)incEndEst:(id)sender
{
//    NSLog(@"Increment end estimate!");
    if (endEst == -1)
    {
//        NSLog(@"Initializing...");
        [self setEndEstimate:[presenter getAudioDuration]];
    }
    else
    {
        [self setEndEstimate:(endEst + 0.001)];
    }
}
- (void)decEndEst:(id)sender
{
//    NSLog(@"Decrement end estimate!");
    if (endEst == -1)
    {
//        NSLog(@"Initializing...");
        [self setEndEstimate:[presenter getAudioDuration]];
    }
    else
    {
        [self setEndEstimate:(endEst - 0.001)];
    }
}
- (IBAction)updateStartEstValueChanged:(id)sender
{
    NSString *text = ((UITextField *)sender).text;
    NSScanner *scan = [NSScanner scannerWithString:text];
    double doubleVal;
    if ([scan scanDouble:&doubleVal] && [scan isAtEnd])
    {
//        NSLog(@"Setting start estimate to %f.", doubleVal);
        [self setStartEstimate:doubleVal];
    }
    else
    {
        // If invalid and not empty, try to fall back on the previous estimate.
        if([text isEqualToString:@""] || startEst == -1)
        {
//            NSLog(@"Resetting start estimate.");
            [self resetStartEstimate];
        }
        else
        {
            [self setStartEstimate:startEst];
        }
    }
}
- (IBAction)updateEndEstValueChanged:(id)sender
{
    NSString *text = ((UITextField *)sender).text;
    NSScanner *scan = [NSScanner scannerWithString:text];
    double doubleVal;
    if ([scan scanDouble:&doubleVal] && [scan isAtEnd])
    {
//        NSLog(@"Setting end estimate to %f.", doubleVal);
        [self setEndEstimate:doubleVal];
    }
    else
    {
        // If invalid and not empty, try to fall back on the previous estimate.
        if([text isEqualToString:@""] || endEst == -1)
        {
//            NSLog(@"Resetting end estimate.");
            [self resetEndEstimate];
        }
        else
        {
            [self setEndEstimate:endEst];
        }
    }
}



- (IBAction)openAdvancedOptions:(id)sender
{
    NSLog(@"Open advanced options!");
}




- (IBAction)revertOriginalLoop:(id)sender
{
    currentDurationRank = -1;
    [self updateAllResults];
}
- (IBAction)prevDuration:(id)sender
{
    currentDurationRank--;
    [self updateAllResults];
//    NSLog(@"Previous duration!");
}
- (IBAction)nextDuration:(id)sender
{
    currentDurationRank++;
    [self updateAllResults];
//    NSLog(@"Next duration!");
}
- (IBAction)prevEndpoints:(id)sender
{
    currentPairRanks[currentDurationRank] = [NSNumber numberWithLong:[currentPairRanks[currentDurationRank] integerValue] - 1];
    [self updateAllEndpointResults];
//    NSLog(@"Previous endpoints!");
}
- (IBAction)nextEndpoints:(id)sender
{
    currentPairRanks[currentDurationRank] = [NSNumber numberWithLong:[currentPairRanks[currentDurationRank] integerValue] + 1];
    [self updateAllEndpointResults];
//    NSLog(@"Next endpoints!");
}

// Helper function to update all results-related display and storage for a for a given duration rank.
- (void)updateAllResults
{
    [self updateLoop:currentDurationRank];
    [self updateResultsDisplay:currentDurationRank];
    [self updateResultScrollButtons];
}
// Like updateAllResults, but doesn't update the loop duration view.
- (void)updateAllEndpointResults
{
    [self updateLoop:currentDurationRank];
    [self updateEndpointsDisplay:currentDurationRank];
    [self updateEndpointScrollButtons];
}

// Helper function to update the loop point in the DB.
- (void)updateLoop:(NSInteger)durationRank
{
    if (durationRank == -1)
    {
        [self setLoopStart:[AudioPlayer frameToTime:(UInt32)[[originalLoopInfo objectForKey:@"startFrame"] unsignedIntegerValue]]];
        [self setLoopEnd:[AudioPlayer frameToTime:(UInt32)[[originalLoopInfo objectForKey:@"endFrame"] unsignedIntegerValue]]];
    }
    else
    {
        NSInteger endpointsRank = [currentPairRanks[durationRank] integerValue];
        [self setLoopStart:[AudioPlayer frameToTime:(UInt32)[[loopFinderResults objectForKey:@"startFrames"][durationRank][endpointsRank] unsignedIntegerValue]]];
        [self setLoopEnd:[AudioPlayer frameToTime:(UInt32)[[loopFinderResults objectForKey:@"endFrames"][durationRank][endpointsRank] unsignedIntegerValue]]];
    }
}

// Helper functions to enable/disable the result scrolling buttons as needed
- (void)updateResultScrollButtons
{
    [self updatePreviousDurationButton];
    [self updateNextDurationButton];
    [self updateEndpointScrollButtons];
}
// Updates only the endpoint scroll buttons.
- (void)updateEndpointScrollButtons
{
    [self updatePreviousEndpointsButton];
    [self updateNextEndpointsButton];
}
- (void)updatePreviousDurationButton
{
    // Disable at -1, since that's the original loop point.
    if (currentDurationRank < 0)
    {
        [self disableButton:loopDurationView:previousDurationButton];
    }
    else
    {
        [self enableButton:loopDurationView:previousDurationButton];
    }
}
- (void)updateNextDurationButton
{
    if (currentDurationRank >= (NSInteger)[[loopFinderResults objectForKey:@"baseDurations"] count] - 1)
    {
        [self disableButton:loopDurationView:nextDurationButton];
    }
    else
    {
        [self enableButton:loopDurationView:nextDurationButton];
    }
}
- (void)updatePreviousEndpointsButton
{
    if (currentDurationRank < 0 || [currentPairRanks[currentDurationRank] integerValue] <= 0)
    {
        [self disableButton:loopEndpointView:previousEndpointsButton];
    }
    else
    {
        [self enableButton:loopEndpointView:previousEndpointsButton];
    }
}
- (void)updateNextEndpointsButton
{
    if (currentDurationRank < 0 || [currentPairRanks[currentDurationRank] integerValue] >= (NSInteger)[[loopFinderResults objectForKey:@"startFrames"][currentDurationRank] count] - 1)
    {
        [self disableButton:loopEndpointView:nextEndpointsButton];
    }
    else
    {
        [self enableButton:loopEndpointView:nextEndpointsButton];
    }
}

// Helper functions to enable/disable a button in a subview programmatically
- (void)enableButton:(UIView *)subview :(NSInteger)tag
{
    UIButton *button = (UIButton* )([subview viewWithTag:tag]);
    button.alpha = 1;
    [button setUserInteractionEnabled:YES];
}
- (void)disableButton:(UIView *)subview :(NSInteger)tag
{
    UIButton *button = (UIButton* )([subview viewWithTag:tag]);
    button.alpha = 0.35;
    [button setUserInteractionEnabled:NO];
}

// Helper function to display the current loop results.
- (void)updateResultsDisplay:(NSInteger)durationRank
{
    [self updateDurationDisplay:durationRank];
    [self updateEndpointsDisplay:durationRank];
}
// Helper function to display the currentDuration
- (void)updateDurationDisplay:(NSInteger)durationRank
{
    if (durationRank == -1) // Original loop
    {
        [self updateText:loopDurationView:durationRankLabel:@"Rank: Original Loop"];
        [self updateText:loopDurationView:durationConfidenceLabel:@"Confidence: ---"];
        [self setDurationLabel:(UInt32)[[originalLoopInfo objectForKey:@"duration"] unsignedIntegerValue]];
    }
    else
    {
        [self updateText:loopDurationView:durationRankLabel:[NSString stringWithFormat:@"Rank: %li", 1+durationRank]];
        [self updateText:loopDurationView:durationConfidenceLabel:[NSString stringWithFormat:@"Confidence: %.2f%%", 100*[[loopFinderResults objectForKey:@"confidences"][durationRank] doubleValue]]];
        [self setDurationLabel:(UInt32)[[loopFinderResults objectForKey:@"baseDurations"][durationRank] unsignedIntegerValue]];
    }
}
// Helper function to display the an endpoint pair of a duration of some rank.
- (void)updateEndpointsDisplay:(NSInteger)durationRank
{
    if (durationRank == -1) // Original loop
    {
        [self updateText:loopEndpointView:endpointsRankLabel:@"Rank: Original Loop"];
        [self setStartEndpointLabel:(UInt32)[[originalLoopInfo objectForKey:@"startFrame"] unsignedIntegerValue]];
        [self setEndEndpointLabel:(UInt32)[[originalLoopInfo objectForKey:@"endFrame"] unsignedIntegerValue]];
    }
    else
    {
        NSInteger endpointsRank = [currentPairRanks[durationRank] integerValue];
        [self updateText:loopEndpointView:endpointsRankLabel:[NSString stringWithFormat:@"Rank: %li", 1+endpointsRank]];
        [self setStartEndpointLabel:(UInt32)[[loopFinderResults objectForKey:@"startFrames"][durationRank][endpointsRank] unsignedIntegerValue]];
        [self setEndEndpointLabel:(UInt32)[[loopFinderResults objectForKey:@"endFrames"][durationRank][endpointsRank] unsignedIntegerValue]];
    }
}
// Helper functions to change the time quantity labels from frame values.
- (void)setDurationLabel:(UInt32)frameDuration
{
    [self updateText:loopDurationView:durationLabel:[NSString stringWithFormat:@"Duration: %.6fs", [AudioPlayer frameToTime:frameDuration]]];
}
- (void)setStartEndpointLabel:(UInt32)frameStart
{
    [self updateText:loopEndpointView:startEndpointLabel:[NSString stringWithFormat:@"Start: %.6fs", [AudioPlayer frameToTime:frameStart]]];
}
- (void)setEndEndpointLabel:(UInt32)frameEnd
{
    [self updateText:loopEndpointView:endEndpointLabel:[NSString stringWithFormat:@"End: %.6fs", [AudioPlayer frameToTime:frameEnd]]];
}


@end
