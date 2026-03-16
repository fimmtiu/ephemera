# Design for a Mastodon picture-posting bot

We're going to create a bot that posts pictures to the ActivityPub-based social network Mastodon on a regular basis. It will run in a Docker container and store its media in an S3-compatible file storage service.

This design should be broken down into many small single-purpose tasks, suitable for performing by a single run of a single agent, which will be farmed out to subagents. ALWAYS WRITE THE SPECS FIRST.

## Desired behaviour

The container has five parts:
* `ephemera`, a Rails application for managing the picture collection
* `postpic`, a command-line tool for doing the actual posting to Mastodon.
* `register`, a command-line tool for [creating a new Mastodon client app](https://docs.joinmastodon.org/client/token/)
* `Mapi`, shared code in the Rails app's `lib` directory for a Mastodon API client
* a reverse nginx proxy to handle SSL connections

The Docker container on which it runs will be based on the latest stable Debian, and needs certbot, nginx, Ruby, cron, and SQLite installed.

### ephemera (Rails application)

We'll create a Rails app called `ephemera`. The Rails application uses Rails 8 and has a SQLite database for back-end storage. The app will run on localhost port 3000 — it should not be directly accessible from the Internet. It uses Rails 8's authentication generator (https://guides.rubyonrails.org/security.html) to build a simple authentication system.

Once a user is logged in, they should be able to do the following:

* Picture management:
  - Upload one or more image files to S3
  - Annotate each image file with metadata: an alt-text field, a hashtags field, and a "sensitive content" field (see below).
  - Delete existing files
  - Change the order in which files are posted
* Mastodon functionality:
  - Display and change the Mastodon profile information for its Mastodon account
  - Get a list of followers for its Mastodon account
  - View a log of postings that this program has made to Mastodon — image, date, time.

The `order` field starts at `1`. When adding a new Picture, the `order` column should be set to `MAX(order) + 1`. If the order of a picture is changed, then the order of all subsequent pictures should be incremented (for later pictures) or decremented (for pictures between the original order and the new order) so that there are no duplicates. The `order` column should be unique, and the application code should ensure that there are never gaps in the monotonically increasing sequence. (In other words, `MAX(order)` and `COUNT()` on the `pictures` table should give the same result.)

When uploading image files, we want to remove any EXIF tags that could potentially disclose data about the image's author. We want to allowlist EXIF tags that are strictly desribing the image data (FNumber, ExposureTime, ISOSpeedRatings, FocalLength, ImageWidth, ImageLength, WhiteBalance, MeteringMode, et cetera), but forbid all others. We **must** expunge any tags that describe GPS information, date/time, camera make or model, serial numbers, or other potentially sensitive information. If you're not sure whether a tag should be allowlisted, ask me.

Required models will include:
* Picture (picture metadata + the S3 URL for the image)
* Log (`posted_at` datetime, image ID, and order of posted image)
* The Current, User, and Session models created by the Rails 8 authentication generator

The Mastodon profile is not a model because we want to fetch the data from the Mastodon server instead of storing it locally. If you want to add other models, ask me first.

### postpic (command-line tool)

We'll create a command-line program called `postpic` which lives in the Rails app's `bin` directory and shares as much code with it as feasible, including the Mastodon API code. When run, it will:

1. Determine which picture is scheduled to be posted next
2. Retrieve its image file from S3
3. Use the Mapi library to upload that picture to the Mastodon server as a media attachment
4. Use the Mapi library to create a new status featuring that attachment
5. Update which picture is scheduled to be posted next
6. Write an entry to the posting log in the database
7. Delete the image file on disk

Algorithm to find the next scheduled picture:
1. We determine the order of the last posted picture by selecting `MAX(posted_at)` from Log and using the `order` from that row. If there is no such row, we default to `1`.
2. We select the picture with that order + 1. If no picture with that order exists, we default to `1`.

This should ensure that we wrap around to the start of the picture collection once we've posted all of the pictures.

When creating a status, if the picture metadata includes a non-blank "sensitive content" field, set the `sensitive` flag to true and set the `spoiler_text` field to the contents of the "sensitive content" metadata.

Every three days at 10:11 AM Pacific time, a cron job executes `postpic` to post the next scheduled picture.

### Mapi (Mastodon API client library)

It should be located in the `lib` directory of the Rails app and be contained in a Ruby module called `Mapi`. We will
need only the following functionality:
* Create a new client application
* OAuth authentication flow
* Logging in as a user
* Displaying and editing the user's profile
* Creating statuses

When authenticating, only request the OAuth scopes which are required for the above functionality.

Mastodon API docs can be found here: https://docs.joinmastodon.org/api/

The Mastodon credentials (client ID, client secret, user name, etc.) and server settings (app name, server host/port,
etc.) will be hard-coded in a `mastodon.json` config file in the Rails app's `config` directory.

### register (command-line tool)

We'll create a command-line program called `register` which lives in the Rails app's `bin` directory and shares as much code with it as feasible, including the Mastodon API code. When run, it uses the Mapi library to make a `POST /api/v1/apps` request as described in https://docs.joinmastodon.org/client/token/, then saves the returned client ID and secret to the `config/mastodon.json` config file.

The app name and server URL should be read from `config/mastodon.json`.

### nginx

We want an nginx reverse proxy in front of the Rails app to proxy SSL connections. It should accept connections on port 443 and proxy them to localhost port 3000 (the `ephemera` app). Everything should live in the same container.

It will use certbot to automatically refresh a Let's Encrypt SSL certificate. Every 85 days, we want to run `certbot --nginx run` from cron to download and install a new SSL cert.
