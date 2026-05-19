/// Tab indices for [HomePage] — shifts when the owner "Listings" tab is shown.
class HomeTabs {
  const HomeTabs({required this.showListings});

  final bool showListings;

  int get catalog => 0;
  int get listings => 1;
  int get bookings => showListings ? 2 : 1;
  int get wallet => showListings ? 3 : 2;
  int get profile => showListings ? 4 : 3;

  int indexAfterAddingListingsTab(int currentIndex) {
    if (!showListings || currentIndex <= 0) return currentIndex;
    return currentIndex + 1;
  }
}
