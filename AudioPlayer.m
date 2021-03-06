//
//  AudioPlayer.m
//  LoopMusic
//
//  Created by Cheng Hann Gan on 5/9/16.
//  Copyright © 2016 Cheng Hann Gan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioPlayer.h"

/// The number of frames that have to match for the loop finder to accept a time.
static const UInt32 NUMMATCHINGFRAMES = 1;
/// The range of the loop finder's search.
static const float SEARCHRANGE = 1;
/// The tolerance of the loop finder's search.
static const float SEARCHTOLERANCE = 300;

@implementation AudioPlayer

@synthesize pauseTime;

- (id)init
{
    self = [super init];
    _audioController = [[AEAudioController alloc] initWithAudioDescription:AEAudioStreamBasicDescriptionNonInterleaved16BitStereo
                                                             inputEnabled:false];
    _audioController.automaticLatencyManagement = false;
    /// Holds error messages that may occur during audio controller initialization.
    NSError *error;
    bool result = [_audioController start:&error];
    if (!result)
    {
        NSLog(@"%@", [error description]);
    }
    
    pauseTime = 0;
    [self resetLoopCounter];
    [self startFreeTimer];
    
    return self;
}

/*!
 * Starts the free timer if it isn't already started.
 */
- (void)startFreeTimer
{
    if (!freeTimer)
    {
        freeTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                     target:self
                                                   selector:@selector(checkFree:)
                                                   userInfo:nil
                                                    repeats:YES];
    }
}

/*!
 * Checks if memory can be freed.
 * @param timer The timer that called this function.
 */
- (void)checkFree:(NSTimer *)timer
{
    if (freeData)
    {
        for (int i = 0; i < 2; i++)
        {
            free(freeData->playingList->mBuffers[i].mData);
        }
        free(freeData->playingList);
        free(freeData);
        freeData = nil;
    }
    if (!_playing)
    {
        [freeTimer invalidate];
        freeTimer = nil;
    }
}

- (NSTimeInterval)currentTime
{
    return _playing ? audioData->currentFrame / (NSTimeInterval)FRAMERATE : pauseTime;
}

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
    NSInteger lastFrame = audioData ? (NSInteger)audioData->numFrames - 1 : 0;
    bufferAudioData->currentFrame = MAX(0, MIN(lastFrame, round(currentTime * FRAMERATE)));
}

- (float)volume
{
    return fminf(_volume * _globalVolume, 1);
}

- (void)setVolume:(float)volume
{
    if (volume < 0)
    {
        volume = 0;
    }
    _volume = volume;
}

- (void)decrementVolume:(float)volumeDec
{
    [self setVolume:_volume - volumeDec];
}

- (void)setGlobalVolume:(float)globalVolume
{
    if (globalVolume < 0)
    {
        globalVolume = 0;
    }
    _globalVolume = globalVolume;
}

- (bool)playing
{
    return _playing;
}

- (UInt32)frameDuration
{
    return bufferAudioData->numFrames;
}
- (double)duration
{
    return bufferAudioData->numFrames / (NSTimeInterval)FRAMERATE;
}

- (UInt32)loopStartFrame
{
    return _loopStart;
}

- (NSTimeInterval)loopStart
{
    return [AudioPlayer frameToTime:_loopStart];
}

- (void)setLoopStart:(NSTimeInterval)loopStart
{
    _loopStart = [AudioPlayer timeToFrame:loopStart];
}

- (UInt32)loopEndFrame
{
    return _loopEnd;
}

- (NSTimeInterval)loopEnd
{
    return [AudioPlayer frameToTime:_loopEnd];
}

- (void)setLoopEnd:(NSTimeInterval)loopEnd
{
    _loopEnd = [AudioPlayer timeToFrame:loopEnd];
}

- (bool)loading
{
    return audioData->loading;
}

- (void)setLoading:(bool)loading
{
    if (audioData)
    {
        audioData->loading = loading;
    }
}

- (void)play
{
    _playing = true;
    if ([self numChannels] == 0)
    {
        [_audioController addChannels:@[_blockChannel]];
    }
    [self startFreeTimer];
    self.currentTime = pauseTime;
}

/*!
 *Stops playback of the audio player.
 */
- (void)stopPlayback
{
    _playing = false;
    if ([self numChannels] > 0)
    {
        [_audioController removeChannels:@[_blockChannel]];
    }
}
- (void)pause
{
    pauseTime = self.currentTime;
    [self stopPlayback];
}

- (void)stop
{
    pauseTime = 0;
    [self stopPlayback];
}

- (NSUInteger)getLoopCount
{
    return loopCount;
}
- (void)resetLoopCounter
{
    loopCount = 0;
}
- (double)getRepeatNumber:(double)elapsedTime
{
    // Use a more robust time-based method, rather than a loop-based method. This allows for jumping around in playback, while still having around the desired number of repeats in playback time.
    return (elapsedTime * FRAMERATE - _loopStart) / (_loopEnd - _loopStart);
}

/*!
 * Gets the number of active channels in the audio controller.
 * @return The number of active channels in the audio controller.
 */
- (NSInteger)numChannels
{
    return [[_audioController channels] count];
}

- (void)initAudioPlayer:(NSURL *)newURL :(NSError *)error
{
    AEAudioFileLoaderOperation *operation = [[AEAudioFileLoaderOperation alloc] initWithFileURL:newURL
                                                                         targetAudioDescription:_audioController.audioDescription];
    [operation start];
    if (operation.error)
    {
        error = operation.error;
    }
    else
    {
        /// Audio data to be loaded into the buffer.
        AudioData *newData = malloc(sizeof(AudioData));
        newData->numFrames = operation.lengthInFrames;
        newData->playingList = operation.bufferList;
        newData->loading = false;
        newData->currentFrame = 0;
        bufferAudioData = newData;
        
        if (!_blockChannel)
        {
            _blockChannel =
            [AEBlockChannel channelWithBlock:^(const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
            {
                AudioData *oldData = self->audioData;
                self->audioData = self->bufferAudioData;
                if (oldData != self->audioData)
                {
                    self->freeData = oldData;
                }
                for (int i = 0; i < frames; i++)
                {
                    for (int j = 0; j < 2; j++)
                    {
                        float currentVolume = self->_volume * self->_globalVolume;
                        if (currentVolume > 1)
                        {
                            currentVolume = 1;
                        }
                        ((SInt16 *)audio->mBuffers[j].mData)[i] = ((SInt16 *)self->audioData->playingList->mBuffers[j].mData)[self->audioData->currentFrame] * currentVolume;
                    }
                    self->audioData->currentFrame++;
                    if (self->audioData->currentFrame >= self->audioData->numFrames)
                    {
                        self->audioData->currentFrame = 0;
                        self->loopCount++;
                    }
                    else if (!self->audioData->loading && self->audioData->currentFrame >= self->_loopEnd)
                    {
                        self->audioData->currentFrame = self->_loopStart;
                        self->loopCount++;
                    }
                }
            }];
        }
    }
}

- (AudioData *)getAudioData
{
    return audioData;
}

- (NSMutableArray *)findLoopTime
{
    /// Acceptable start points.
    NSMutableArray *foundPoints = [[NSMutableArray alloc] init];
    if (_loopEnd > audioData->numFrames - NUMMATCHINGFRAMES)
    {
        return foundPoints;
    }
    
    /// The range of the search in frames.
    UInt32 searchRangeFrames = SEARCHRANGE * FRAMERATE;
    if (audioData->numFrames < searchRangeFrames << 1 || _loopStart >= _loopEnd )
    {
        return foundPoints;
    }
    
    /// The end frames that must match with the start frames to be accepted.
    SInt16 endFrames[NUMMATCHINGFRAMES * 2];
    
    /// For loop iterator.
    UInt32 i, j;
    /// Counter for filling arrays.
    UInt32 arrayCounter = 0;
    for (i = _loopEnd; i < _loopEnd + NUMMATCHINGFRAMES; i++)
    {
        for (j = 0; j < 2; j++)
        {
            endFrames[arrayCounter++] = ((SInt16 *)audioData->playingList->mBuffers[j].mData)[i];
        }
    }
    
    /// Whether an acceptable start point was found.
    bool found;
    /// The start point being examined.
    UInt32 foundPoint = -1;
    for (UInt32 k = 0; k < searchRangeFrames; k++)
    {
        for (SInt32 n = -1; n < 2; n += 2)
        {
            arrayCounter = 0;
            foundPoint = _loopStart + k * n;
            if (foundPoint >= audioData->numFrames)
            {
                continue;
            }
            found = true;
            for (i = foundPoint; i < foundPoint + NUMMATCHINGFRAMES; i++)
            {
                for (j = 0; j < 2; j++)
                {
                    /// The current sample from the loop start being compared.
                    SInt16 startSample = ((SInt16 *)audioData->playingList->mBuffers[j].mData)[i];
                    /// The current sample from the loop end being compared.
                    SInt16 endSample = endFrames[arrayCounter++];
                    if (abs(endSample - startSample) > SEARCHTOLERANCE)
                    {
                        found = false;
                        break;
                    }
                }
                if (!found)
                {
                    break;
                }
            }
            if (found)
            {
                break;
            }
        }
        if (found)
        {
            /// The found start point to add to the array.
            NSNumber *number = [NSNumber numberWithDouble:foundPoint / (NSTimeInterval)FRAMERATE];
            [foundPoints addObject:number];
        }
    }
    
    return foundPoints;
}


+ (UInt32)timeToFrame:(NSTimeInterval)time
{
    return (UInt32)lround(time * FRAMERATE);
}
+ (NSTimeInterval)frameToTime:(UInt32)frame
{
    return frame / (NSTimeInterval)FRAMERATE;
}

@end
