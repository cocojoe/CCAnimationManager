//
//  MainScene.m
//  PROJECTNAME
//
//  Created by Viktor on 10/10/13.
//  Copyright (c) 2013 Apportable. All rights reserved.
//

#import "MainScene.h"

@implementation MainScene

- (void) didLoadFromCCB
{
    _animationManager = _simple.userObject;
    //[_animationManager debug];
    
    [self pressedReset:nil];
    _pause = NO;
}

- (void) pressedMove:(id)sender
{
    CCLOG(@"pressedMove");
    [_animationManager runAnimationsForSequenceNamed:@"move" tweenDuration:0];
}

- (void) pressedKF:(id)sender
{
    CCLOG(@"pressedKF: %d",_keyFrame);
    
    /*
    [_animationManager jumpToKeyFrame:_keyFrame];
    if(_keyFrame==5)
        _keyFrame = 0;
    else
        _keyFrame++;
    */
    [_animationManager setPlaybackSpeed:-0.50f];
}


- (void) pressedTime:(id)sender
{
    CCLOG(@"pressedTime: %f",_time);
    /*
    [_animationManager jumpToTime:_time];
    if(_time==4)
        _time = 0;
    else
        _time+=0.25f;
     */
    _pause=!_pause;
    [_animationManager setPaused:_pause];
}

- (void) pressedReset:(id)sender
{
    [_animationManager reset];
    CCLOG(@"pressedReset:");
    _keyFrame = 0;
    _time     = 0;
    [_animationManager setPlaybackSpeed:1.0f];
}

@end
