//
//  MainScene.m
//  PROJECTNAME
//
//  Created by Viktor on 10/10/13.
//  Copyright (c) 2013 Apportable. All rights reserved.
//

#import "MainScene.h"

#define SPEED_SLOW          0.25f
#define SPEED_NORMAL        1.0f
#define SPEED_FAST          1.75f

@implementation MainScene

- (void) didLoadFromCCB
{
    _animationManagerSimple = _simple.userObject;
    _animationManagerBeast  = _beast.userObject;
}

- (void) pressedPlay:(id)sender {
    [_animationManagerSimple runAnimationsForSequenceNamed:@"move" tweenDuration:0];
}

- (void) pressedSkip:(id)sender {
    [_animationManagerSimple timeSeekForSequenceNamed:@"move" time:2.1f];
}

- (void) pressedSlow:(id)sender {
    [_animationManagerBeast setPlaybackSpeed:SPEED_SLOW];
}

- (void) pressedNormal:(id)sender {
    [_animationManagerBeast setPlaybackSpeed:SPEED_NORMAL];
}

- (void) pressedFast:(id)sender {
    [_animationManagerBeast setPlaybackSpeed:SPEED_FAST];
}

- (void) pressedPauseBeast:(id)sender {
    [_animationManagerBeast setPaused:![_animationManagerBeast paused]];
}

- (void) pressedPauseSimple:(id)sender {
    [_animationManagerSimple setPaused:![_animationManagerSimple paused]];
}


@end
