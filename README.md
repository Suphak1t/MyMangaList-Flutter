# MyMangaList

Flutter app for keeping a Manga list, publishing chapters, and reading public Manga. Users can register, sign in, search and filter, manage their own Manga, and report public Manga. Admins manage users and review reports.

## Run on Windows Desktop

1. Start the PHP API and MySQL through XAMPP. See the [MyMangaList API repository](https://github.com/Suphak1t/MyMangaList-API) for database setup.
2. Check the API URL in `lib/config.dart`. The current value is `http://localhost/mymangalist_api`.
3. Enable Windows Developer Mode (Flutter plugins need symlink support), then run `flutter pub get` and `flutter run -d windows` from this folder.

Accounts created in the app have the `user` role. Admin access is granted in MySQL, not during registration. The API checks the bearer token and keeps private Manga and editing tied to the owner.

Choose up to five genres from the searchable list, optionally select a cover image, and create a Manga. Open its detail page to add chapters over time. Each chapter has a number, optional title, and one PDF or up to 15 images. Image filenames are sorted alphabetically, so use names such as `001.png`, `002.png`. Chapters can stay as drafts or be published. Visibility `private` is owner-only; `public` Manga and its published chapters can be read by other signed-in users. Release status can start as `ongoing` or `coming_soon`; editing also allows `hiatus` and `completed`. Owners can edit or delete Manga and chapters, replace a cover, and replace each chapter's PDF or image set.

The dashboard shows covers, chapter counts, and unique reader counts. The public view shows a Top 10 ordered by readers and a button to the search page. The My Manga view keeps a local search box. On the search page, choose multiple genres from the complete genre checklist and filter by release status, visibility, title, and author. Signed-in readers can rate a public Manga from one to five stars; owners cannot rate their own work. One account contributes at most one view per Manga, counted when it opens a published chapter. The dashboard has a light/dark theme switch. The reader shows previous- and next-chapter buttons together after the last image in vertical mode; page/PDF mode uses the top bar.

Signed-in readers can comment on the whole Manga from its detail page or on a chapter from the reader. A commenter can remove their own comment; the Manga owner can remove comments on their Manga.

When another readable chapter exists, the reader offers **ตอนถัดไป** on the final PDF/page view, or after the last image in vertical scrolling mode. Readers can report a public Manga from its detail page with a written reason. The admin panel shows users, Manga/comment counts, account suspension controls, and a report queue. Admins can open a reported Manga to inspect its published chapters before dismissing the report, hiding or deleting the Manga, or suspending its uploader. Hidden Manga remains available to its owner but is not publicly readable; admins can restore it. Admin roles are still assigned in MySQL only.

In the reader, use the settings button to choose vertical scrolling or one page at a time. The page width starts at 700 px and can be adjusted from 400 to 1200 px, or set to fill the window. In one-page mode, tap the left half to go back or the right half to go forward. Dragging still scrolls a long image. Reader settings apply to the current open chapter.

## Checks

Run `flutter analyze` and `flutter test` after changing Flutter code.
