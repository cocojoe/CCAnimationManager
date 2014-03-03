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
    [_animationManager debug];
    _time = 0;
}

- (void) pressedMove:(id)sender
{
    CCLOG(@"pressedMove");
    [_animationManager runAnimationsForSequenceNamed:@"move" tweenDuration:0];
    _time = 0;
}

- (void) pressedKF:(id)sender
{
    CCLOG(@"pressedKF");
    [_animationManager jumpToTime:_time];
    _time+=1;
}

@end
