//
//  MainScene.h
//  PROJECTNAME
//
//  Created by Viktor on 10/10/13.
//  Copyright (c) 2013 Apportable. All rights reserved.
//

#import "CCNode.h"

@interface MainScene : CCNode {
    CCBAnimationManager* _animationManager;
    CCNode* _simple;
    int _keyFrame;
    float _time;
}

@end
