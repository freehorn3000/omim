#import "Common.h"
#import "LocationManager.h"
#import "MapsAppDelegate.h"
#import "MWMActivityViewController.h"
#import "MWMAPIBar.h"
#import "MWMBasePlacePageView.h"
#import "MWMDirectionView.h"
#import "MWMiPadPlacePage.h"
#import "MWMiPhoneLandscapePlacePage.h"
#import "MWMiPhonePortraitPlacePage.h"
#import "MWMPlacePage.h"
#import "MWMPlacePageActionBar.h"
#import "MWMPlacePageEntity.h"
#import "MWMPlacePageNavigationBar.h"
#import "MWMPlacePageViewManager.h"
#import "MWMPlacePageViewManagerDelegate.h"
#import "Statistics.h"

#import "3party/Alohalytics/src/alohalytics_objc.h"

#include "geometry/distance_on_sphere.hpp"
#include "platform/measurement_utils.hpp"

extern NSString * const kAlohalyticsTapEventKey;
extern NSString * const kBookmarksChangedNotification;

typedef NS_ENUM(NSUInteger, MWMPlacePageManagerState)
{
  MWMPlacePageManagerStateClosed,
  MWMPlacePageManagerStateOpen
};

@interface MWMPlacePageViewManager () <LocationObserver>
{
  unique_ptr<UserMarkCopy> m_userMark;
}

@property (weak, nonatomic) UIViewController * ownerViewController;
@property (nonatomic, readwrite) MWMPlacePageEntity * entity;
@property (nonatomic) MWMPlacePage * placePage;
@property (nonatomic) MWMPlacePageManagerState state;
@property (nonatomic) MWMDirectionView * directionView;

@property (weak, nonatomic) id<MWMPlacePageViewManagerProtocol> delegate;

@end

@implementation MWMPlacePageViewManager

- (instancetype)initWithViewController:(UIViewController *)viewController
                              delegate:(id<MWMPlacePageViewManagerProtocol>)delegate
{
  self = [super init];
  if (self)
  {
    self.ownerViewController = viewController;
    self.delegate = delegate;
    self.state = MWMPlacePageManagerStateClosed;
  }
  return self;
}

- (void)hidePlacePage
{
  [self.placePage hide];
}

- (void)dismissPlacePage
{
  [self.delegate placePageDidClose];
  self.state = MWMPlacePageManagerStateClosed;
  [self.placePage dismiss];
  [[MapsAppDelegate theApp].m_locationManager stop:self];
  GetFramework().GetBalloonManager().RemovePin();
  m_userMark = nullptr;
  self.entity = nil;
  self.placePage = nil;
}

- (void)showPlacePageWithUserMark:(unique_ptr<UserMarkCopy>)userMark
{
  NSAssert(userMark, @"userMark cannot be nil");
  m_userMark = move(userMark);
  [[MapsAppDelegate theApp].m_locationManager start:self];
  self.entity = [[MWMPlacePageEntity alloc] initWithUserMark:m_userMark->GetUserMark()];
  self.state = MWMPlacePageManagerStateOpen;
  if (IPAD)
    [self setPlacePageForiPad];
  else
    [self setPlacePageForiPhoneWithOrientation:self.ownerViewController.interfaceOrientation];
  [self configPlacePage];
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
  [self rotateToOrientation:orientation];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [self rotateToOrientation:size.height > size.width ? UIInterfaceOrientationPortrait : UIInterfaceOrientationLandscapeLeft];
}

- (void)rotateToOrientation:(UIInterfaceOrientation)orientation
{
  if (!self.placePage)
    return;

  if (IPAD)
  {
    self.placePage.parentViewHeight = self.ownerViewController.view.width;
    [(MWMiPadPlacePage *)self.placePage updatePlacePageLayoutAnimated:NO];
  }
  else
  {
    [self.placePage dismiss];
    [self setPlacePageForiPhoneWithOrientation:orientation];
    [self configPlacePage];
  }
}

- (void)configPlacePage
{
  if (self.entity.type == MWMPlacePageEntityTypeMyPosition)
  {
    BOOL hasSpeed;
    self.entity.category = [[MapsAppDelegate theApp].m_locationManager formattedSpeedAndAltitude:hasSpeed];
  }
  self.placePage.parentViewHeight = self.ownerViewController.view.height;
  [self.placePage configure];
  self.placePage.topBound = self.topBound;
  self.placePage.leftBound = self.leftBound;
  [self refreshPlacePage];
}

- (void)refreshPlacePage
{
  [self.placePage show];
  [self updateDistance];
}

- (void)setPlacePageForiPad
{
  [self.placePage dismiss];
  self.placePage = [[MWMiPadPlacePage alloc] initWithManager:self];
}

- (void)updateMyPositionSpeedAndAltitude
{
  if (self.entity.type != MWMPlacePageEntityTypeMyPosition)
    return;
  BOOL hasSpeed = NO;
  [self.placePage updateMyPositionStatus:[[MapsAppDelegate theApp].m_locationManager
                                          formattedSpeedAndAltitude:hasSpeed]];
}

- (void)setPlacePageForiPhoneWithOrientation:(UIInterfaceOrientation)orientation
{
  if (self.state == MWMPlacePageManagerStateClosed)
    return;

  switch (orientation)
  {
    case UIInterfaceOrientationLandscapeLeft:
    case UIInterfaceOrientationLandscapeRight:
      if (![self.placePage isKindOfClass:[MWMiPhoneLandscapePlacePage class]])
        self.placePage = [[MWMiPhoneLandscapePlacePage alloc] initWithManager:self];
      break;

    case UIInterfaceOrientationPortrait:
    case UIInterfaceOrientationPortraitUpsideDown:
      if (![self.placePage isKindOfClass:[MWMiPhonePortraitPlacePage class]])
        self.placePage = [[MWMiPhonePortraitPlacePage alloc] initWithManager:self];
      break;

    case UIInterfaceOrientationUnknown:
      break;
  }
}

- (void)addSubviews:(NSArray *)views withNavigationController:(UINavigationController *)controller
{
  if (controller)
    [self.ownerViewController addChildViewController:controller];
  [self.delegate addPlacePageViews:views];
}

- (void)buildRoute
{
  [[Statistics instance] logEvent:kStatPlacePage
                   withParameters:@{kStatAction : kStatBuildRoute, kStatValue : kStatDestination}];
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"ppRoute"];
  m2::PointD const & destination = m_userMark->GetUserMark()->GetOrg();
  m2::PointD const myPosition([MapsAppDelegate theApp].m_locationManager.lastLocation.mercator);
  [self.delegate buildRouteFrom:MWMRoutePoint(myPosition)
                             to:{destination, self.placePage.basePlacePageView.titleLabel.text}];
}

- (void)routeFrom
{
  [[Statistics instance] logEvent:kStatPlacePage
                   withParameters:@{kStatAction : kStatBuildRoute, kStatValue : kStatSource}];
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"ppRoute"];
  [self.delegate buildRouteFrom:self.target];
  [self dismissPlacePage];
}

- (void)routeTo
{
  [[Statistics instance] logEvent:kStatPlacePage
                   withParameters:@{kStatAction : kStatBuildRoute, kStatValue : kStatDestination}];
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"ppRoute"];
  [self.delegate buildRouteTo:self.target];
  [self dismissPlacePage];
}

- (MWMRoutePoint)target
{
  UserMark const * m = m_userMark->GetUserMark();
  m2::PointD const & org = m->GetOrg();
  return m->GetMarkType() == UserMark::Type::MY_POSITION ?
                          MWMRoutePoint(org) :
                          MWMRoutePoint(org, self.placePage.basePlacePageView.titleLabel.text);
}

- (void)share
{
  [[Statistics instance] logEvent:kStatPlacePage withParameters:@{kStatAction : kStatShare}];
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"ppShare"];
  MWMPlacePageEntity * entity = self.entity;
  NSString * title = entity.bookmarkTitle ? entity.bookmarkTitle : entity.title;
  CLLocationCoordinate2D const coord = CLLocationCoordinate2DMake(entity.point.x, entity.point.y);
  MWMActivityViewController * shareVC =
      [MWMActivityViewController shareControllerForLocationTitle:title
                                                        location:coord
                                                      myPosition:NO];
  [shareVC presentInParentViewController:self.ownerViewController
                              anchorView:self.placePage.actionBar.shareButton];
}

- (void)apiBack
{
  ApiMarkPoint const * p = static_cast<ApiMarkPoint const *>(m_userMark->GetUserMark());
  NSURL * url = [NSURL URLWithString:@(GetFramework().GenerateApiBackUrl(*p).c_str())];
  [[UIApplication sharedApplication] openURL:url];
  [self.delegate apiBack];
}

- (void)changeBookmarkCategory:(BookmarkAndCategory)bac;
{
  BookmarkCategory const * category = GetFramework().GetBmCategory(bac.first);
  Bookmark const * bookmark = category->GetBookmark(bac.second);
  m_userMark.reset(new UserMarkCopy(bookmark, false));
}

- (void)addBookmark
{
  Framework & f = GetFramework();
  BookmarkData data = BookmarkData(self.entity.title.UTF8String, f.LastEditedBMType());
  size_t const categoryIndex = f.LastEditedBMCategory();
  size_t const bookmarkIndex =
      f.GetBookmarkManager().AddBookmark(categoryIndex, m_userMark->GetUserMark()->GetOrg(), data);
  self.entity.bac = make_pair(categoryIndex, bookmarkIndex);
  self.entity.type = MWMPlacePageEntityTypeBookmark;
  BookmarkCategory const * category = f.GetBmCategory(categoryIndex);
  Bookmark const * bookmark = category->GetBookmark(bookmarkIndex);
  m_userMark.reset(new UserMarkCopy(bookmark, false));
  f.ActivateUserMark(bookmark);
  f.Invalidate();
  [NSNotificationCenter.defaultCenter postNotificationName:kBookmarksChangedNotification
                                                    object:nil
                                                  userInfo:nil];
  [self updateDistance];
}

- (void)removeBookmark
{
  Framework & f = GetFramework();
  BookmarkCategory * bookmarkCategory = f.GetBookmarkManager().GetBmCategory(self.entity.bac.first);
  UserMark const * bookmark = bookmarkCategory->GetBookmark(self.entity.bac.second);
  BookmarkAndCategory const bookmarkAndCategory = f.FindBookmark(bookmark);
  self.entity.type = MWMPlacePageEntityTypeRegular;
  PoiMarkPoint const * poi = f.GetAddressMark(bookmark->GetOrg());
  m_userMark.reset(new UserMarkCopy(poi, false));
  f.ActivateUserMark(poi);
  if (bookmarkCategory)
  {
    bookmarkCategory->DeleteBookmark(bookmarkAndCategory.second);
    bookmarkCategory->SaveToKMLFile();
  }
  f.Invalidate();
  [NSNotificationCenter.defaultCenter postNotificationName:kBookmarksChangedNotification
                                                    object:nil
                                                  userInfo:nil];
  [self updateDistance];
}

- (void)reloadBookmark
{
  [self.entity synchronize];
  [self.placePage reloadBookmark];
  [self updateDistance];
}

- (void)dragPlacePage:(CGRect)frame
{
  [self.delegate dragPlacePage:frame];
}

- (void)onLocationUpdate:(location::GpsInfo const &)info
{
  [self updateDistance];
  [self updateMyPositionSpeedAndAltitude];
}

- (void)updateDistance
{
  NSString * distance = [self distance];
  self.directionView.distanceLabel.text = distance;
  [self.placePage setDistance:distance];
}

- (NSString *)distance
{
  CLLocation * location = [MapsAppDelegate theApp].m_locationManager.lastLocation;
  if (!location || !m_userMark)
    return @"";
  string distance;
  CLLocationCoordinate2D const coord = location.coordinate;
  ms::LatLon const target = MercatorBounds::ToLatLon(m_userMark->GetUserMark()->GetOrg());
  MeasurementUtils::FormatDistance(ms::DistanceOnEarth(coord.latitude, coord.longitude,
                                                       target.lat, target.lon), distance);
  return @(distance.c_str());
}

- (void)onCompassUpdate:(location::CompassInfo const &)info
{
  CLLocation * location = [MapsAppDelegate theApp].m_locationManager.lastLocation;
  if (!location || !m_userMark)
    return;

  CGFloat const angle = ang::AngleTo(location.mercator, m_userMark->GetUserMark()->GetOrg()) + info.m_bearing;
  CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI_2 - angle);
  [self.placePage setDirectionArrowTransform:transform];
  [self.directionView setDirectionArrowTransform:transform];
}

- (void)showDirectionViewWithTitle:(NSString *)title type:(NSString *)type
{
  MWMDirectionView * directionView = self.directionView;
  UIView * ownerView = self.ownerViewController.view;
  directionView.titleLabel.text = title;
  directionView.typeLabel.text = type;
  [ownerView addSubview:directionView];
  [ownerView endEditing:YES];
  [directionView setNeedsLayout];
  [self.delegate updateStatusBarStyle];
  [(MapsAppDelegate *)[UIApplication sharedApplication].delegate disableStandby];
  [self updateDistance];
}

- (void)hideDirectionView
{
  [self.directionView removeFromSuperview];
  [self.delegate updateStatusBarStyle];
  [(MapsAppDelegate *)[UIApplication sharedApplication].delegate enableStandby];
}

- (void)changeHeight:(CGFloat)height
{
  if (!IPAD)
    return;
  ((MWMiPadPlacePage *)self.placePage).height = height;
}

#pragma mark - Properties

- (MWMDirectionView *)directionView
{
  if (!_directionView)
    _directionView = [[MWMDirectionView alloc] initWithManager:self];
  return _directionView;
}

- (BOOL)isDirectionViewShown
{
  return self.directionView.superview != nil;
}

- (void)setTopBound:(CGFloat)topBound
{
  _topBound = self.placePage.topBound = topBound;
}

- (void)setLeftBound:(CGFloat)leftBound
{
  _leftBound = self.placePage.leftBound = leftBound;
}

@end
