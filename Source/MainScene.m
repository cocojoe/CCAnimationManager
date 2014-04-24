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
#define SPEED_FAST          1.50f

@implementation MainScene

- (void) didLoadFromCCB
{
    _animationManagerBeast  = _beast.userObject;
}


- (void) pressedReverse:(id)sender {
    //[_animationManagerBeast setPlaybackSpeed:[_animationManagerBeast playbackSpeed]*-1];
    [[CCDirector sharedDirector] replaceScene:[CCBReader loadAsScene:@"MainScene"]];
    
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


@end
