//
//  RGChangeArray.m
//  CampTalk
//
//  Created by renge on 2019/12/18.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGArray.h"
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    RGArrayChangeTypeNew,
    RGArrayChangeTypeDelete,
    RGArrayChangeTypeUpdate,
} RGArrayChangeType;

@implementation RGArrayChange
@synthesize modifications = _modifications;
@synthesize insertions = _insertions;
@synthesize deletions = _deletions;

- (instancetype)initWithIndexSets:(NSArray <NSIndexSet *> *)indexSets types:(NSArray <NSNumber *> *)types done:(BOOL)done {
    if (self = [super init]) {
        _done = done;
        [types enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            RGArrayChangeType type = obj.integerValue;
            NSIndexSet *indexSet = indexSets[idx];
            switch (type) {
                case RGArrayChangeTypeNew:
                    _insertions = indexSet;
                    break;
                case RGArrayChangeTypeDelete:
                    _deletions = indexSet;
                    break;
                case RGArrayChangeTypeUpdate:
                    _modifications = indexSet;
                default:
                    break;
            }
        }];
    }
    return self;
}

- (instancetype)initWithIndexSet:(NSIndexSet *)indexSet type:(RGArrayChangeType)type done:(BOOL)done {
    if (self = [super init]) {
        _done = done;
        switch (type) {
            case RGArrayChangeTypeNew:
                _insertions = indexSet;
                break;
            case RGArrayChangeTypeDelete:
                _deletions = indexSet;
                break;
            case RGArrayChangeTypeUpdate:
                _modifications = indexSet;
            default:
                break;
        }
    }
    return self;
}

- (NSIndexSet *)modifications {
    if (!_modifications) {
        return [NSIndexSet indexSet];
    }
    return _modifications;
}

-  (NSIndexSet *)deletions {
    if (!_deletions) {
        return [NSIndexSet indexSet];
    }
    return _deletions;
}

-  (NSIndexSet *)insertions {
    if (!_insertions) {
        return [NSIndexSet indexSet];
    }
    return _insertions;
}

- (NSArray<NSIndexPath *> *)deletionsInSection:(NSUInteger)section {
    return [self indexPathsInSection:section withIndexes:self.deletions];
}

- (NSArray<NSIndexPath *> *)insertionsInSection:(NSUInteger)section {
    return [self indexPathsInSection:section withIndexes:self.insertions];
}

- (NSArray<NSIndexPath *> *)modificationsInSection:(NSUInteger)section {
    return [self indexPathsInSection:section withIndexes:self.modifications];
}

- (NSArray<NSIndexPath *> *)deletionIndexPaths {
    return [self indexPathsInSection:self.defaultSection withIndexes:self.deletions];
}

- (NSArray<NSIndexPath *> *)insertionsIndexPaths {
    return [self indexPathsInSection:self.defaultSection withIndexes:self.insertions];
}

- (NSArray<NSIndexPath *> *)modificationIndexPaths {
    return [self indexPathsInSection:self.defaultSection withIndexes:self.modifications];
}

- (NSArray<NSIndexPath *> *)indexPathsInSection:(NSUInteger)section withIndexes:(NSIndexSet *)sets {
    if (!sets.count) {
        return @[];
    }
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:sets.count];
    [sets enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [array addObject:[NSIndexPath indexPathForRow:idx inSection:section]];
    }];
    return array;
}

- (NSString *)description {
    NSString *desc = [NSString stringWithFormat:@"\nchange:------->\n    deletes:%@\n    inserts:%@\n    modifys:%@\n    done:%d\n<-------\n",
                      [self descriptionOfIndexSet:_deletions],
                      [self descriptionOfIndexSet:_insertions],
                      [self descriptionOfIndexSet:_modifications],
                      self.done];
    return desc;
}

- (NSString *)descriptionOfIndexSet:(NSIndexSet *)indexSet {
    NSString *desc = indexSet.description;
    NSRange range = [desc rangeOfString:@">"];
    return [desc substringFromIndex:range.location + range.length];
}

@end

@interface RGArray ()

@property (nonatomic, strong) NSMutableArray *mArray;
@property (nonatomic, strong) NSPointerArray *delegates;

@end

@implementation RGArray

#pragma mark - RGFunction

- (void)addDelegate:(id<RGArrayChangeDelegate>)delegate {
    if (delegate) {
        void(^mainBlock)(void) = ^{
            if (![[self.delegates allObjects] containsObject:delegate]) {
                [self.delegates addPointer:(__bridge void * _Nullable)(delegate)];
            }
        };
        if ([NSThread isMainThread]) {
            mainBlock();
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                mainBlock();
            });
        }
    }
}

- (void)removeDelegate:(id<RGArrayChangeDelegate>)delegate {
    void(^mainBlock)(void) = ^{
        NSInteger index = [[self.delegates allObjects] indexOfObject:delegate];
        if (index != NSNotFound) {
            [self.delegates removePointerAtIndex:index];
        }
    };
    if ([NSThread isMainThread]) {
        mainBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            mainBlock();
        });
    }
}

- (NSPointerArray *)delegates {
    if (!_delegates) {
        _delegates = [NSPointerArray weakObjectsPointerArray];
    }
    return _delegates;
}

- (void)sendModificationsAtIndexes:(NSIndexSet *)indexes {
    [self __callbackWithIndexes:indexes type:RGArrayChangeTypeUpdate];
}

- (void)sendModificationsWithObject:(id)anObject {
    NSUInteger index = [self indexOfObject:anObject];
    if (index == NSNotFound) {
        return;
    }
    [self __callbackWithIndexes:[NSIndexSet indexSetWithIndex:index] type:RGArrayChangeTypeUpdate];
}

#pragma mark - Private

- (BOOL)_isRGEqualOfObj:(id<RGChangeProtocol>)obj other:(id<RGChangeProtocol>)other {
    if (self.equalRule) {
        return self.equalRule(obj, other);
    }
    if ([obj respondsToSelector:@selector(rg_arrayObjIsEqual:)]) {
        return [obj rg_arrayObjIsEqual:other];
    }
    if ([other respondsToSelector:@selector(rg_arrayObjIsEqual:)]) {
        return [other rg_arrayObjIsEqual:obj];
    }
    if (obj == other) {
        return YES;
    }
    return NO;
}

- (BOOL)_hasModificationOfObj:(id<RGChangeProtocol>)obj old:(id<RGChangeProtocol>)old {
    if (self.modifyRule) {
        return self.modifyRule(old, obj);
    }
    if ([obj respondsToSelector:@selector(rg_arrayObjHasModification:)]) {
        return [obj rg_arrayObjHasModification:old];
    }
    return YES;
}

- (void)__callbackWithIndexes:(NSIndexSet *)index type:(RGArrayChangeType)type {
    if (!index.count) {
        return;
    }
    RGArrayChange *change = [[RGArrayChange alloc] initWithIndexSet:index type:type done:YES];
    [self __enumerateDelegate:^(id<RGArrayChangeDelegate> obj) {
        [obj changeArray:self change:change];
    }];
}

- (void)__callbackWithIndexes:(NSIndexSet *)index type:(RGArrayChangeType)type done:(BOOL)done {
    if (!index.count) {
        return;
    }
    RGArrayChange *change = [[RGArrayChange alloc] initWithIndexSet:index type:type done:done];
    [self __enumerateDelegate:^(id<RGArrayChangeDelegate> obj) {
        [obj changeArray:self change:change];
    }];
}

- (void)__callbackWithIndexes:(NSArray <NSIndexSet *> *)indexes types:(NSArray <NSNumber *> *)types done:(BOOL)done {
    __block BOOL hasCount = NO;
    [indexes enumerateObjectsUsingBlock:^(NSIndexSet * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.count > 0) {
            hasCount = YES;
            *stop = YES;
        }
    }];
    if (!hasCount) {
        return;
    }
    
    RGArrayChange *change = [[RGArrayChange alloc] initWithIndexSets:indexes types:types done:done];
    
    [self __enumerateDelegate:^(id<RGArrayChangeDelegate> obj) {
        [obj changeArray:self change:change];
    }];
}

- (void)__enumerateDelegate:(void (NS_NOESCAPE ^)(id <RGArrayChangeDelegate> obj))block {
    NSArray <id<RGArrayChangeDelegate>> *delegates = [self.delegates allObjects];
    for (int i = 0; i < delegates.count; i++) {
        id <RGArrayChangeDelegate> delegate = delegates[i];
        if (block) {
            block(delegate);
        }
    }
}

#pragma mark - Array

- (instancetype)initWithCapacity:(NSUInteger)numItems {
    if (self = [super init]) {
        _mArray = [NSMutableArray arrayWithCapacity:numItems];
    }
    return self;
}

- (NSUInteger)count {
    return _mArray.count;
}

- (id)objectAtIndex:(NSUInteger)index {
    return _mArray[index];
}

+ (instancetype)arrayWithArray:(NSArray *)array {
    RGArray *obj = [super arrayWithArray:array];
    if ([array isKindOfClass:RGArray.class]) {
        RGArray *old = (RGArray *)array;
        obj.equalRule = old.equalRule;
        obj.modifyRule = old.modifyRule;
        obj.changeByStep = old.changeByStep;
        obj.headBetter = old.headBetter;
    }
    return obj;
}

- (id)copy {
    RGArray *obj = [self.class arrayWithArray:self];
    return obj;
}

- (id)mutableCopy {
    RGArray *obj = [self.class arrayWithArray:self];
    return obj;
}

+ (void)enumerateNumberWithBegin:(NSUInteger)begin length:(NSUInteger)length reverse:(BOOL)reverse usingBlock:(void (^)(NSUInteger idx, BOOL * _Nonnull stop))block {
    if (length == 0) {
        return;
    }
    NSUInteger max = begin + length;
    if (reverse) {
        for (NSUInteger i = max - 1; i >= begin && i < max; i--) {
            BOOL stop = NO;
            block(i, &stop);
            if (stop) {
                break;
            }
        }
    } else {
        for (NSUInteger i = begin; i < max; i++) {
            BOOL stop = NO;
            block(i, &stop);
            if (stop) {
                break;
            }
        }
    }
}

#pragma mark - NSMutableArray

- (void)addObject:(id)anObject {
    [_mArray addObject:anObject];
    [self __callbackWithIndexes:[NSIndexSet indexSetWithIndex:self.count - 1] type:RGArrayChangeTypeNew];
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index {
    [_mArray insertObject:anObject atIndex:index];
    [self __callbackWithIndexes:[NSIndexSet indexSetWithIndex:index] type:RGArrayChangeTypeNew];
}

- (void)removeLastObject {
    if (_mArray.count) {
        [_mArray removeLastObject];
        [self __callbackWithIndexes:[NSIndexSet indexSetWithIndex:self.count] type:RGArrayChangeTypeNew];
    }
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    [_mArray removeObjectAtIndex:index];
    [self __callbackWithIndexes:[NSIndexSet indexSetWithIndex:index] type:RGArrayChangeTypeDelete];
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject {
    [_mArray replaceObjectAtIndex:index withObject:anObject];
    [self __callbackWithIndexes:[NSIndexSet indexSetWithIndex:index] type:RGArrayChangeTypeUpdate];
}

#pragma mark - NSMutableArray<ObjectType> (NSExtendedMutableArray)

- (void)addObjectsFromArray:(NSArray *)otherArray {
    NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(_mArray.count, otherArray.count)];
    [_mArray addObjectsFromArray:otherArray];
    [self __callbackWithIndexes:set type:RGArrayChangeTypeNew];
}

- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2 {
    [_mArray exchangeObjectAtIndex:idx1 withObjectAtIndex:idx2];
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    [set addIndex:idx1];
    [set addIndex:idx2];
    [self __callbackWithIndexes:set type:RGArrayChangeTypeUpdate];
}

- (void)removeAllObjects {
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.count)];
    [_mArray removeAllObjects];
    [self __callbackWithIndexes:indexes type:RGArrayChangeTypeDelete];
}

- (void)removeObject:(id)anObject inRange:(NSRange)range {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = range.location; i < (range.location + range.length); i++) {
        id obj = _mArray[i];
        if ([obj isEqual:anObject]) {
            [indexes addIndex:i];
        }
    }
    [self removeObjectsAtIndexes:indexes];
}

- (void)removeObject:(id)anObject {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < _mArray.count; i++) {
        id obj = _mArray[i];
        if ([obj isEqual:anObject]) {
            [indexes addIndex:i];
        }
    }
    [self removeObjectsAtIndexes:indexes];
}

- (void)removeObjectIdenticalTo:(id)anObject inRange:(NSRange)range {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = range.location; i < (range.location + range.length); i++) {
        id obj = _mArray[i];
        if (obj == anObject) {
            [indexes addIndex:i];
        }
    }
    [self removeObjectsAtIndexes:indexes];
}

- (void)removeObjectIdenticalTo:(id)anObject {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < _mArray.count; i++) {
        id obj = _mArray[i];
        if (obj == anObject) {
            [indexes addIndex:i];
        }
    }
    [self removeObjectsAtIndexes:indexes];
}

- (void)removeObjectsFromIndices:(NSUInteger *)indices numIndices:(NSUInteger)cnt {
    
}

- (void)removeObjectsInArray:(NSArray *)otherArray {
    NSIndexSet *indexes = [_mArray indexesOfObjectsPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [otherArray containsObject:obj];
    }];
    [self removeObjectsAtIndexes:indexes];
}

- (void)removeObjectsInRange:(NSRange)range {
    [_mArray removeObjectsInRange:range];
    [self __callbackWithIndexes:[NSIndexSet indexSetWithIndexesInRange:range] type:RGArrayChangeTypeDelete];
}

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(nonnull NSArray *)otherArray range:(NSRange)otherRange {
    NSArray *sub = [otherArray subarrayWithRange:otherRange];
    [self replaceObjectsInRange:range withObjectsFromArray:sub];
}

- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(nonnull NSArray *)otherArray {
    if (self.changeByStep) {
        [self stepReplaceObjectsInRange:range withObjectsFromArray:otherArray];
        return;
    }
    if (otherArray.count == 0) {
        NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:range];
        [self removeObjectsAtIndexes:set];
        return;
    }
    if (range.length == 0) {
        NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(range.location, otherArray.count)];
        [self insertObjects:otherArray atIndexes:set];
        return;
    }
    
    BOOL reverse = self.headBetter;
    NSMutableIndexSet *deletes = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *inserts = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *reloads = [NSMutableIndexSet indexSet];
    
    NSMutableArray *mArray = [NSMutableArray arrayWithArray:_mArray];
    
    NSUInteger mCount = range.length + range.location;
    NSUInteger mLoc = range.location;
    
    NSInteger offsetCount = otherArray.count - range.length;
    if (offsetCount > 0) {
        // insert
        __block NSUInteger offset = 0;
        [self.class enumerateNumberWithBegin:0 length:otherArray.count reverse:reverse usingBlock:^(NSUInteger oIdx, BOOL * _Nonnull stop) {
            NSUInteger mIdx = mLoc;
            mIdx += (reverse ? (mCount - 1 - offset) : offset);
            mIdx += (reverse ? inserts.count : -inserts.count);
            
            offset++;
            if (mIdx < mArray.count) {
                id <RGChangeProtocol> oObj = otherArray[oIdx];
                id <RGChangeProtocol> mObj = mArray[mIdx];
                
                if ([self _isRGEqualOfObj:mObj other:oObj]) {
                    if ([self _hasModificationOfObj:oObj old:mObj]) {
                        [reloads addIndex:mIdx];
                    }
                } else {
                    if (offsetCount == inserts.count) {
                        [reloads addIndex:mIdx];
                    } else {
                        [inserts addIndex:mLoc + oIdx];
                    }
                }
            } else {
                [inserts addIndex:mLoc + oIdx];
            }
        }];
    } else if (offsetCount <= 0) {
        // delete
        __block NSUInteger oIdx = reverse ? otherArray.count - 1 : 0;
        [self.class enumerateNumberWithBegin:mLoc length:mCount reverse:reverse usingBlock:^(NSUInteger mIdx, BOOL * _Nonnull stop) {
            if (oIdx < otherArray.count) {
                id <RGChangeProtocol> mObj = mArray[mIdx];
                id <RGChangeProtocol> oObj = otherArray[oIdx];
                if ([self _isRGEqualOfObj:mObj other:oObj]) {
                    if ([self _hasModificationOfObj:oObj old:mObj]) {
                        [reloads addIndex:mIdx];
                    }
                    reverse ? oIdx-- : oIdx++;
                } else {
                    if (-offsetCount == deletes.count) {
                        [reloads addIndex:mIdx];
                        reverse ? oIdx-- : oIdx++;
                    } else {
                        [deletes addIndex:mIdx];
                    }
                }
            } else {
                [deletes addIndex:mIdx];
            }
        }];
    }
    
    [otherArray enumerateObjectsUsingBlock:^(NSObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:NSObject.class] && obj.rg_needModifyChange) {
            obj.rg_needModifyChange = NO;
        }
    }];
    
    // callback
    [mArray replaceObjectsInRange:range withObjectsFromArray:otherArray];
    NSMutableArray *release = _mArray;
    _mArray = mArray;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [release count];
    });
    
    [self __callbackWithIndexes:@[deletes,
                                  inserts,
                                  reloads]
                          types:@[
                              @(RGArrayChangeTypeDelete),
                              @(RGArrayChangeTypeNew),
                              @(RGArrayChangeTypeUpdate)]
                           done:YES
     ];
}

- (void)stepReplaceObjectsInRange:(NSRange)range withObjectsFromArray:(nonnull NSArray *)otherArray {
    if (otherArray.count == 0) {
        NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:range];
        [self removeObjectsAtIndexes:set];
        return;
    }
    if (range.length == 0) {
        NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(range.location, otherArray.count)];
        [self insertObjects:otherArray atIndexes:set];
        return;
    }
    
    BOOL headBetter = self.headBetter;
    NSMutableIndexSet *deletes = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *inserts = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *reloads = [NSMutableIndexSet indexSet];
    
    NSMutableArray *mArray = [NSMutableArray arrayWithArray:_mArray];
    NSMutableArray *mArrayDeletes = nil;
    NSMutableArray *mArrayInserts = nil;
    
    NSMutableIndexSet *finds = [NSMutableIndexSet indexSet];
    NSUInteger mCount = range.length + range.location;
    NSUInteger mLoc = range.location;
    
    [self.class enumerateNumberWithBegin:mLoc length:mCount reverse:headBetter usingBlock:^(NSUInteger mIdx, BOOL * _Nonnull stop) {
        id <RGChangeProtocol> mObj = mArray[mIdx];
        id findObj = nil;
        for (NSUInteger nIdx = 0; nIdx < otherArray.count; nIdx++) {
            if ([finds containsIndex:nIdx]) {
                continue;
            }
            id <RGChangeProtocol> nObj = otherArray[nIdx];
            if ([self _isRGEqualOfObj:nObj other:mObj]) {
                findObj = nObj;
                [finds addIndex:nIdx];
                break;
            }
        }
        if (!findObj) {
            [deletes addIndex:mIdx];
        }
    }];
    
    if (deletes.count) {
        [mArray removeObjectsAtIndexes:deletes];
        mArrayDeletes = [NSMutableArray arrayWithArray:mArray];
        mCount -= deletes.count;
    }
    
    // insert
    [finds removeAllIndexes];
    NSMutableArray *insetObjs = [NSMutableArray array];
    [self.class enumerateNumberWithBegin:0 length:otherArray.count reverse:headBetter usingBlock:^(NSUInteger nIdx, BOOL * _Nonnull stop) {
        if (mCount + inserts.count == otherArray.count) {
            *stop = YES;
            return;
        }
        id <RGChangeProtocol> nObj = otherArray[nIdx];
        id findObj = nil;
        for (NSUInteger mIdx = mLoc; mIdx < mCount; mIdx++) {
            if ([finds containsIndex:mIdx]) {
                continue;
            }
            id mObj = mArray[mIdx];
            if ([self _isRGEqualOfObj:nObj other:mObj]) {
                findObj = mObj;
                [finds addIndex:mIdx];
                break;
            }
        }
        if (!findObj) {
            [insetObjs addObject:nObj];
            [inserts addIndex:mLoc + nIdx];
        }
    }];
    if (inserts.count) {
//        NSLog(@"inserts: -->>>>\ntemp:%@\ninsetObjs:%@\ninserts:%@\notherArray:%@\n<<<<<--", temp, insetObjs, inserts, otherArray);
        [mArray insertObjects:insetObjs atIndexes:inserts];
        mArrayInserts = [NSMutableArray arrayWithArray:mArray];
        mCount += inserts.count;
    }
    
    // reload
    NSMutableArray *reloadObjs = [NSMutableArray array];
    for (NSUInteger nIdx = 0; nIdx < otherArray.count; nIdx++) {
        NSUInteger mIdx = mLoc + nIdx;
        id <RGChangeProtocol> mObj = mArray[mIdx];
        id <RGChangeProtocol> nObj = otherArray[nIdx];
        if ([self _isRGEqualOfObj:nObj other:mObj]) {
            if ([self _hasModificationOfObj:nObj old:mObj]) {
                [reloads addIndex:mIdx];
                [reloadObjs addObject:nObj];
            }
        } else {
            [reloads addIndex:mIdx];
            [reloadObjs addObject:nObj];
        }
    }
    
    [otherArray enumerateObjectsUsingBlock:^(NSObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:NSObject.class] && obj.rg_needModifyChange) {
            obj.rg_needModifyChange = NO;
        }
    }];
    
    if (deletes.count) {
        _mArray = mArrayDeletes;
        [self __callbackWithIndexes:deletes type:RGArrayChangeTypeDelete done:reloads.count <= 0 && inserts.count <= 0];
    }
    
    if (inserts.count) {
        _mArray = mArrayInserts;
        [self __callbackWithIndexes:inserts type:RGArrayChangeTypeNew done:reloads.count <= 0];
    }
    
    if (reloads.count) {
        [mArray replaceObjectsAtIndexes:reloads withObjects:reloadObjs];
        _mArray = mArray;
        [self __callbackWithIndexes:reloads type:RGArrayChangeTypeUpdate done:YES];
    }
}

- (void)__back__replaceObjectsInRange:(NSRange)range withObjectsFromArray:(nonnull NSArray *)otherArray deleteAtLast:(BOOL)deleteAtLast {
    if (otherArray.count == 0) {
        NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:range];
        [self removeObjectsAtIndexes:set];
        return;
    }
    if (range.length == 0) {
        NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(range.location, otherArray.count)];
        [self insertObjects:otherArray atIndexes:set];
        return;
    }
    
    NSMutableIndexSet *deletes = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *inserts = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *reloads = [NSMutableIndexSet indexSet];
    
    NSMutableArray *temp = [NSMutableArray arrayWithArray:_mArray];
    
    // delete
    NSMutableIndexSet *finds = [NSMutableIndexSet indexSet];
    
    void(^pickDeletes)(NSUInteger mIdx) = ^(NSUInteger mIdx) {
        id <RGChangeProtocol> mObj = temp[mIdx];
        id findObj = nil;
        for (NSUInteger nIdx = 0; nIdx < otherArray.count; nIdx++) {
            if ([finds containsIndex:nIdx]) {
                continue;
            }
            id <RGChangeProtocol> nObj = otherArray[nIdx];
            if ([self _isRGEqualOfObj:nObj other:mObj]) {
                findObj = nObj;
                [finds addIndex:nIdx];
                break;
            }
        }
        if (!findObj) {
            [deletes addIndex:mIdx];
        }
    };
    
    NSUInteger mCount = range.length + range.location;
    NSUInteger mLoc = range.location;
    
    if (deleteAtLast) {
        for (NSUInteger mIdx = range.location; mIdx < mCount; mIdx++) {
            pickDeletes(mIdx);
        }
    } else {
        for (NSUInteger mIdx = mCount - 1; mIdx >= mLoc && mIdx < mCount; mIdx--) {
            pickDeletes(mIdx);
        }
    }
    
    [temp removeObjectsAtIndexes:deletes];
    
    mCount -= deletes.count;
    
    // insert
    NSMutableArray *insetObjs = [NSMutableArray array];
    for (NSUInteger nIdx = 0; nIdx < otherArray.count; nIdx++) {
        id <RGChangeProtocol> nObj = otherArray[nIdx];
        id findObj = nil;
        for (NSUInteger mIdx = mLoc; mIdx < mCount; mIdx++) {
            id mObj = temp[mIdx];
            if ([self _isRGEqualOfObj:nObj other:mObj]) {
                findObj = mObj;
                break;
            }
        }
        if (!findObj) {
            [insetObjs addObject:nObj];
            [inserts addIndex:mLoc + nIdx];
        }
    }
    
    [temp insertObjects:insetObjs atIndexes:inserts];
    
    // reload
    [deletes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL contain = [inserts containsIndex:idx];
        if (contain) {
            [deletes removeIndex:idx];
            [inserts removeIndex:idx];
            [reloads addIndex:idx];
            *stop = YES;
        }
    }];
    
    __block BOOL needReload = (otherArray.count > range.length);
    
    for (NSUInteger nIdx = 0; nIdx < otherArray.count; nIdx++) {
        NSUInteger mIdx = mLoc + nIdx;
        if ([inserts containsIndex:mIdx]) {
            continue;
        }
        id <RGChangeProtocol> mObj = temp[mIdx];
        id <RGChangeProtocol> nObj = otherArray[nIdx];
        if (![reloads containsIndex:mIdx]) {
            if ([self _isRGEqualOfObj:nObj other:mObj]) {
                if ([self _hasModificationOfObj:nObj old:mObj]) {
                    [reloads addIndex:mIdx];
                }
            } else {
                [reloads addIndex:mIdx];
            }
        }
        [temp replaceObjectAtIndex:mIdx withObject:nObj];
    }
    
    if (needReload) {
        [reloads enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            if ([deletes containsIndex:idx]) {
                *stop = YES;
                needReload = NO;
            }
        }];
    }
    
    if (!needReload) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self __callbackWithIndexes:reloads type:RGArrayChangeTypeUpdate];
        });
        reloads = [NSMutableIndexSet indexSet];
    }
    
    // callback
    NSMutableArray *release = _mArray;
    _mArray = temp;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [release count];
    });
    
    [self __callbackWithIndexes:@[deletes,
                                  inserts,
                                  reloads]
                          types:@[
                              @(RGArrayChangeTypeDelete),
                              @(RGArrayChangeTypeNew),
                              @(RGArrayChangeTypeUpdate)]
                           done:YES];
}

- (void)setArray:(NSArray *)otherArray {
    [self replaceObjectsInRange:NSMakeRange(0, self.count) withObjectsFromArray:otherArray];
}

//- (void)setArray:(NSArray *)otherArray deleteAtLast:(BOOL)deleteAtLast {
//    [self replaceObjectsInRange:NSMakeRange(0, self.count) withObjectsFromArray:otherArray deleteAtLast:deleteAtLast];
//}

- (void)sortUsingFunction:(NSInteger (NS_NOESCAPE *)(id  _Nonnull __strong, id  _Nonnull __strong, void * _Nullable))compare context:(void *)context {
    NSArray *arr = [_mArray sortedArrayUsingFunction:compare context:context];
    [self setArray:arr];
}

- (void)sortUsingSelector:(SEL)comparator {
    NSArray *arr = [_mArray sortedArrayUsingSelector:comparator];
    [self setArray:arr];
}

- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes {
    [_mArray insertObjects:objects atIndexes:indexes];
    [self __callbackWithIndexes:indexes type:RGArrayChangeTypeNew];
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes {
    [_mArray removeObjectsAtIndexes:indexes];
    [self __callbackWithIndexes:indexes type:RGArrayChangeTypeDelete];
}

- (void)replaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(nonnull NSArray *)objects {
    [_mArray replaceObjectsAtIndexes:indexes withObjects:objects];
    [self __callbackWithIndexes:indexes type:RGArrayChangeTypeUpdate];
}

- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx {
    [_mArray setObject:obj atIndexedSubscript:idx];
    [self __callbackWithIndexes:[NSIndexSet indexSetWithIndex:idx] type:RGArrayChangeTypeUpdate];
}

- (void)sortUsingComparator:(NSComparator NS_NOESCAPE)cmptr {
    NSArray *arr = [_mArray sortedArrayUsingComparator:cmptr];
    [self setArray:arr];
}

- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(nonnull NSComparator NS_NOESCAPE)cmptr {
    NSArray *arr = [_mArray sortedArrayWithOptions:opts usingComparator:cmptr];
    [self setArray:arr];
}

#pragma mark - NSArray NSArray<ObjectType> (NSExtendedArray)

- (RGArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    NSArray *array = [_mArray objectsAtIndexes:indexes];
    return [RGArray arrayWithArray:array];
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    return [_mArray objectAtIndexedSubscript:idx];
}

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))block {
    [_mArray enumerateObjectsUsingBlock:block];
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(nonnull void (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))block {
    [_mArray enumerateObjectsWithOptions:opts usingBlock:block];
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts usingBlock:(nonnull void (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))block {
    [_mArray enumerateObjectsAtIndexes:s options:opts usingBlock:block];
}

- (NSUInteger)indexOfObjectPassingTest:(BOOL (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    return [_mArray indexOfObjectPassingTest:predicate];
}

- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)opts passingTest:(nonnull BOOL (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    return [_mArray indexOfObjectWithOptions:opts passingTest:predicate];
}

- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts passingTest:(BOOL (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    return [_mArray indexOfObjectAtIndexes:s options:opts passingTest:predicate];
}

- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    return [_mArray indexesOfObjectsPassingTest:predicate];
}

- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)opts passingTest:(nonnull BOOL (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    return [_mArray indexesOfObjectsWithOptions:opts passingTest:predicate];
}

- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts passingTest:(nonnull BOOL (NS_NOESCAPE^)(id _Nonnull, NSUInteger, BOOL * _Nonnull))predicate {
    return [_mArray indexesOfObjectsAtIndexes:s options:opts passingTest:predicate];
}

- (RGArray *)sortedArrayUsingComparator:(NS_NOESCAPE NSComparator)cmptr {
    NSArray *array = [_mArray sortedArrayUsingComparator:cmptr];
    return [RGArray arrayWithArray:array];
}

- (RGArray *)sortedArrayWithOptions:(NSSortOptions)opts usingComparator:(NS_NOESCAPE NSComparator)cmptr {
    NSArray *array = [_mArray sortedArrayWithOptions:opts usingComparator:cmptr];
    return [RGArray arrayWithArray:array];
}

- (NSUInteger)indexOfObject:(id)obj inSortedRange:(NSRange)r options:(NSBinarySearchingOptions)opts usingComparator:(nonnull NS_NOESCAPE NSComparator)cmp {
    return [_mArray indexOfObject:obj inSortedRange:r options:opts usingComparator:cmp];
}

@end

