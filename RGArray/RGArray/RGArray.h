//
//  RGChangeArray.h
//  CampTalk
//
//  Created by renge on 2019/12/18.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RGArrayChange : NSObject

@property (nonatomic, readonly) NSIndexSet *deletions;
@property (nonatomic, readonly) NSIndexSet *insertions;
@property (nonatomic, readonly) NSIndexSet *modifications;

/// Whether the step-by-step callback of the array is complete
@property (nonatomic, readonly) BOOL done;

- (NSArray<NSIndexPath *> *)deletionsInSection:(NSUInteger)section;
- (NSArray<NSIndexPath *> *)insertionsInSection:(NSUInteger)section;
- (NSArray<NSIndexPath *> *)modificationsInSection:(NSUInteger)section;


/// default 0
@property (nonatomic, assign) NSUInteger defaultSection;

- (NSArray<NSIndexPath *> *)deletionIndexPaths;
- (NSArray<NSIndexPath *> *)insertionsIndexPaths;
- (NSArray<NSIndexPath *> *)modificationIndexPaths;

@end

@class RGArray;

@protocol RGArrayChangeDelegate <NSObject>

- (void)changeArray:(RGArray *)array change:(RGArrayChange *)change;

@end

/// 让数组元素实现该协议 自定义更新的逻辑
@protocol RGChangeProtocol <NSObject>

/// 数组对象增删时，是否是同一个对象的判断逻辑，默认比较对象的地址
- (BOOL)rg_arrayObjIsEqual:(id)object;

/// 同一个对象替换时，是否需要通知代理回调 modifications，默认返回 YES
/// @param old 包含旧数据的对象
- (BOOL)rg_arrayObjHasModification:(id)old;

@end

/// RGArray 继承自OC数组，可以对内部元素的变化（增 删 改 覆盖 排序）作出回调，包含明确的变化位置
@interface RGArray <ObjectType> : NSMutableArray

/// 自定义数组元素是否相等的逻辑判断，不为空时，会忽略 RGChangeProtocol
@property (nonatomic, copy, nullable) BOOL(^equalRule)(ObjectType obj, ObjectType other);
/// 自定义数组元素是否变化的逻辑判断，不为空时，会忽略 RGChangeProtocol
@property (nonatomic, copy, nullable) BOOL(^modifyRule)(ObjectType old, ObjectType young);

/// change callback will called step-by-step. recommended to set it to yes when the list is not refreshed using "reloadRowsAtIndexPaths" or "reloadItemsAtIndexPaths"
@property (nonatomic, assign) BOOL changeByStep;

- (void)addDelegate:(id<RGArrayChangeDelegate>)delegate;
- (void)removeDelegate:(id<RGArrayChangeDelegate>)delegate;

/// 通知代理更新对应的位置
- (void)sendModificationsAtIndexes:(NSIndexSet *)indexes;
- (void)sendModificationsWithObject:(ObjectType)anObject;

/// Step by step callback changes
/// @param range range
/// @param otherArray otherArray
/// @param reverseSearch search order.  The equal element will change more reasonably, if the change position of insertion or deletion is closer to the search order.
- (void)stepReplaceObjectsInRange:(NSRange)range withObjectsFromArray:(nonnull NSArray *)otherArray reverseSearch:(BOOL)reverseSearch;

#pragma mark - NSMutableArray

- (void)addObject:(ObjectType)anObject;
- (void)insertObject:(ObjectType)anObject atIndex:(NSUInteger)index;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(ObjectType)anObject;

#pragma mark - NSMutableArray<ObjectType> (NSExtendedMutableArray)

- (void)addObjectsFromArray:(NSArray<ObjectType> *)otherArray;
- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2;
- (void)removeAllObjects;
- (void)removeObject:(ObjectType)anObject inRange:(NSRange)range;
- (void)removeObject:(ObjectType)anObject;
- (void)removeObjectIdenticalTo:(ObjectType)anObject inRange:(NSRange)range;
- (void)removeObjectIdenticalTo:(ObjectType)anObject;
- (void)removeObjectsFromIndices:(NSUInteger *)indices numIndices:(NSUInteger)cnt API_DEPRECATED("Not supported", macos(10.0,10.6), ios(2.0,4.0), watchos(2.0,2.0), tvos(9.0,9.0));
- (void)removeObjectsInArray:(NSArray<ObjectType> *)otherArray;
- (void)removeObjectsInRange:(NSRange)range;
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray<ObjectType> *)otherArray range:(NSRange)otherRange;
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray<ObjectType> *)otherArray;
- (void)setArray:(NSArray<ObjectType> *)otherArray;
- (void)sortUsingFunction:(NSInteger (NS_NOESCAPE *)(ObjectType,  ObjectType, void * _Nullable))compare context:(nullable void *)context;
- (void)sortUsingSelector:(SEL)comparator;

- (void)insertObjects:(NSArray<ObjectType> *)objects atIndexes:(NSIndexSet *)indexes;
- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(NSArray<ObjectType> *)objects;

- (void)setObject:(ObjectType)obj atIndexedSubscript:(NSUInteger)idx API_AVAILABLE(macos(10.8), ios(6.0), watchos(2.0), tvos(9.0));

- (void)sortUsingComparator:(NSComparator NS_NOESCAPE)cmptr API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));


#pragma mark - NSArray<ObjectType> (NSExtendedArray)

- (RGArray <ObjectType> *)objectsAtIndexes:(NSIndexSet *)indexes;

- (ObjectType)objectAtIndexedSubscript:(NSUInteger)idx API_AVAILABLE(macos(10.8), ios(6.0), watchos(2.0), tvos(9.0));

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (void)enumerateObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

- (NSUInteger)indexOfObjectPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts passingTest:(BOOL (NS_NOESCAPE^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts passingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

- (RGArray<ObjectType> *)sortedArrayUsingComparator:(NSComparator NS_NOESCAPE)cmptr API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
- (RGArray<ObjectType> *)sortedArrayWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));

- (NSUInteger)indexOfObject:(ObjectType)obj inSortedRange:(NSRange)r options:(NSBinarySearchingOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmp API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0)); // binary search

@end

NS_ASSUME_NONNULL_END
