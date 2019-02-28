DROP SCHEMA IF EXISTS A3 CASCADE;
CREATE SCHEMA A3;
SET search_path TO A3;
DROP TABLE IF EXISTS BestSnapUser CASCADE;
DROP TABLE IF EXISTS Email CASCADE;
DROP TABLE IF EXISTS Phone CASCADE;
DROP TABLE IF EXISTS Friend CASCADE;
DROP TABLE IF EXISTS Profile CASCADE;
DROP TABLE IF EXISTS Post CASCADE;
DROP TABLE IF EXISTS Hashtags CASCADE;
DROP TABLE IF EXISTS PostImage CASCADE;			
DROP TABLE IF EXISTS ProfImage CASCADE;
DROP TABLE IF EXISTS TaggedHandles CASCADE;
DROP TABLE IF EXISTS Comment CASCADE;
DROP TRIGGER IF EXISTS hash_password ON BestSnapUser CASCADE;
DROP TRIGGER IF EXISTS mutual_friend ON Friend CASCADE;
DROP TRIGGER IF EXISTS unfriendshing ON Friend CASCADE;
DROP TRIGGER IF EXISTS profupdate ON ProfImage CASCADE;
DROP TRIGGER IF EXISTS delpic ON PostImage CASCADE;
DROP TRIGGER IF EXISTS commcheck ON Comment CASCADE;

-- The User table contains all the users of the app BestSnap
-- 'handle' is the unique username of each user
-- 'password' is the password of the user
CREATE TABLE BestSnapUser(	
	handle VARCHAR PRIMARY KEY,
	password VARCHAR NOT NULL
	
);

-- The Email table contains all the emails of the Users of BestSnap
-- 'email' is the emails of the handle; each handle must have one or more emails
CREATE TABLE Email(
	handle	VARCHAR	REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	email	VARCHAR	UNIQUE,	
	PRIMARY KEY (handle, email)
);

-- The Phone table contains all the phone numbers of the Users of BestSnap
-- 'number' is the phone number of the handle; each handle must have one or more numbers
CREATE TABLE Phone(
	handle	VARCHAR REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	number	VARCHAR(12) UNIQUE, 
	CHECK (number SIMILAR TO '[0-9]{3}-[0-9]{3}-[0-9]{4}'),
	PRIMARY KEY (handle, number)
);

-- The Friend table contains all the friends a user has
-- 'handle1' is the handle of a user
-- 'handle2' is the handle of the friend of 'handle1'
CREATE TABLE Friend(
	handle1 VARCHAR REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	handle2 VARCHAR REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY(handle1, handle2)
);

-- The ProfImage table contains all the Profile Picture Images of a User's Profile
-- 'poster_handle' is the handle of the User's profile 
CREATE TABLE ProfImage (
	uuid 			UUID NOT NULL PRIMARY KEY,
	cameraserial 	VARCHAR NOT NULL,	
	date 			timestamp NOT NULL, 
	poster_handle	VARCHAR NOT NULL REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	longitude		float NOT NULL,		
	latitude		float NOT NULL
);

-- The Profile table contains the single Profile of a User
-- 'firstname' is the first name of the User
-- 'lastname' is the last name of the User
-- 'birthday' is the date of the birthday of the User
-- 'motto' is a free-format 
--  char personal motto of the User
-- 'privacy' dictates if the profile of the User is 'public' or 'private'
-- 'profpic' is the UUID of the profile picture of the profile
-- 'hometown' is the home town of the User
-- 'country' is the home country of the User
CREATE TABLE Profile(
	handle		VARCHAR PRIMARY KEY REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	firstname 	VARCHAR,
	lastname 	VARCHAR,
	birthday	DATE,
	motto		VARCHAR(140),
	privacy		VARCHAR NOT NULL,
	profpic		UUID REFERENCES ProfImage(UUID) ON DELETE SET NULL,
	hometown	VARCHAR,
	country		VARCHAR,
	CHECK (privacy = 'public' OR privacy = 'private')
);

-- The Post table contains all the posts made by all the users of BestSnap
-- 'pid' is the unique post identifier
-- 'description' is a free format text description accompanied with the post
CREATE TABLE Post(
	handle		VARCHAR REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	pID		serial UNIQUE,	
	description	VARCHAR(140) NOT NULL,
	PRIMARY KEY (handle, pID)
);

-- The Hashtag table contains all the hashtags associated with a post
-- 'tag' is the hashtag
CREATE TABLE Hashtags(
	handle		VARCHAR REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	pID		INTEGER REFERENCES Post(pID) ON DELETE CASCADE ON UPDATE CASCADE,
	tag			VARCHAR NOT NULL, 
	CHECK (tag SIMILAR TO '#_+'),
	PRIMARY KEY (handle, pid, tag)
);

-- The Image table contains all the images posted on BestSnap
-- 'uuid' is the Universally Unique Identifier of each individual image
-- 'cameraserial' is the camera serial number that took the picture
-- 'date' is the datetime stamp of the image
-- 'poster-handle' is the handle of the user who took the photo
-- 'pid' is the Post Identification of the post the image was posted on
-- 'longitude' is the longitude of the GPS of where the image was taken
-- 'latitude' is the latitude of the GPS of where the image was taken
CREATE TABLE PostImage (
	uuid 		UUID NOT NULL PRIMARY KEY,
	cameraserial 	VARCHAR NOT NULL,	
	date 		timestamp NOT NULL,
	poster_handle	VARCHAR NOT NULL REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	pID 		INTEGER REFERENCES Post(pID) ON DELETE CASCADE ON UPDATE CASCADE,
	longitude	float NOT NULL,		
	latitude	float NOT NULL
);



-- The TaggedHandles table contains all the handles appearing or tagged in an image
-- 'handle' refers to the tagged handle in an image, there can be 0 or more
CREATE TABLE TaggedHandles(
	uuid 		UUID REFERENCES PostImage(uuid) ON DELETE CASCADE ON UPDATE CASCADE,
	handle 		VARCHAR REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (uuid, handle)
);

-- The Comment table contains all the comments on a specified post
-- 'cID' is the Unique Identifier of every comment
-- 'text' is the text in a comment
-- 'emoji' is the one emoji that may appear in a comment
-- 'addressed-handle' is the handle the comment is addressed to if given
CREATE TABLE Comment(
	cID			serial NOT NULL,
	pID 			INTEGER NOT NULL REFERENCES Post(pID) ON DELETE CASCADE ON UPDATE CASCADE,
	handle 			VARCHAR NOT NULL REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	text			text,
	emoji			VARCHAR,
	addressed_handle	VARCHAR REFERENCES BestSnapUser(handle) ON DELETE CASCADE ON UPDATE CASCADE,
	CHECK (NOT (text IS NULL AND emoji IS NULL AND addressed_handle IS NULL)),	
	CHECK (emoji SIMILAR TO ':_+:'),
	CHECK (handle <> addressed_handle),
	PRIMARY KEY (cID, pID)
);

-- Triggers --

-- HASH PASSWORD UPON INSERTION TRIGGER
-- using md5 for now, it's not salted --

CREATE OR REPLACE FUNCTION hash_password()
	RETURNS TRIGGER AS $hash_password$
BEGIN 
	NEW.password := md5(NEW.password);
	return NEW;
END;
$hash_password$ LANGUAGE PLPGSQL;

CREATE TRIGGER hash_password
        BEFORE INSERT OR UPDATE ON BestSnapUser
        FOR EACH ROW EXECUTE PROCEDURE hash_password();


-- MUTUAL FRIENDSHIP TRIGGER --

CREATE OR REPLACE FUNCTION friendship()
	RETURNS TRIGGER AS $friend$
BEGIN
	INSERT INTO Friend VALUES(NEW.handle2, NEW.handle1);
	RETURN NEW;
END;
$friend$ LANGUAGE PLPGSQL;

CREATE TRIGGER mutual_friend
	AFTER INSERT OR UPDATE ON Friend
	FOR EACH ROW 	
	WHEN (pg_trigger_depth() = 0)
	EXECUTE PROCEDURE friendship();


-- UNFRIEND TRIGGER --

CREATE OR REPLACE FUNCTION unfriending()
	RETURNS TRIGGER AS $unfriend$
BEGIN
	DELETE FROM Friend WHERE (handle1 = OLD.handle2 and handle2 = OLD.handle1);
	RETURN NEW;
END;
$unfriend$ LANGUAGE PLPGSQL;

CREATE TRIGGER unfriending
	AFTER DELETE ON Friend
	FOR EACH ROW 
	WHEN (pg_trigger_depth() = 0)
	EXECUTE PROCEDURE unfriending();


-- Update Profile with ProfImage Trigger --

CREATE OR REPLACE FUNCTION profupdate()
	RETURNS TRIGGER AS $profupdate$
BEGIN
	UPDATE Profile 
	SET profpic = NEW.UUID
	WHERE handle = NEW.poster_handle;
	RETURN NULL;
END;
$profupdate$ LANGUAGE PLPGSQL;

CREATE TRIGGER profupdate
	AFTER INSERT OR UPDATE ON ProfImage
	FOR EACH ROW
	WHEN (pg_trigger_depth() = 0)
	EXECUTE PROCEDURE profupdate();


-- Prevent PostImage from deletion Trigger --

CREATE OR REPLACE FUNCTION delpic()
	RETURNS TRIGGER AS $delpic$
BEGIN 
	RAISE EXCEPTION 'You cannot update or delete a pic without deleting its post!';
END;
$delpic$ LANGUAGE PLPGSQL;

CREATE TRIGGER delpic
	BEFORE DELETE OR UPDATE ON PostImage
	FOR EACH ROW
	WHEN (pg_trigger_depth() = 0)
	EXECUTE PROCEDURE delpic();


-- COMMENT TRIGGER --

CREATE OR REPLACE FUNCTION commcheck()
	RETURNS TRIGGER AS $commcheck$
DECLARE
	pprivacy VARCHAR;
BEGIN	
	pprivacy := (SELECT pf.privacy FROM Post p, Profile pf WHERE (NEW.pID = p.pID and p.handle = pf.handle));


	IF pprivacy = 'private'
	THEN
		IF NOT EXISTS(SELECT f.handle1 FROM Post p, Friend f WHERE (NEW.pID = p.pID and p.handle = f.handle2 and f.handle1 = NEW.handle))
		THEN
			IF NOT EXISTS(SELECT p.handle FROM Post p WHERE (p.handle = NEW.handle))
				THEN
					RAISE EXCEPTION 'no comment 4 u';
				END IF;
		END IF;
	ELSE
		RETURN NEW;	
	END IF;
	RETURN NEW;	
END;
$commcheck$ LANGUAGE PLPGSQL;

CREATE TRIGGER commcheck
	BEFORE INSERT OR UPDATE ON Comment
	FOR EACH ROW
	WHEN (pg_trigger_depth() = 0)
	EXECUTE PROCEDURE commcheck();















