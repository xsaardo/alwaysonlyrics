import { searchSong, fetchPageHTML, extractLyricsFromHTML, cleanLyricsHTML } from './genius.js';

/**
 * Fetch song lyrics from Genius
 * @param {string} artist - The artist name
 * @param {string} songTitle - The song title
 * @param {string} accessToken - Genius API access token
 * @param {Object} options - Optional configuration
 * @param {string} options.albumName - Optional album name for better search accuracy
 * @param {boolean} options.returnSongInfo - If true, returns an object with lyrics and song info
 * @returns {Promise<string|Object>} The cleaned lyrics text, or object with lyrics and song info if returnSongInfo is true
 * @throws {Error} If song is not found or if there's an error fetching lyrics
 */
async function fetchLyrics(artist, songTitle, accessToken, options = {}) {
  const { albumName = '', returnSongInfo = false } = options;

  if (!accessToken) {
    throw new Error('Genius API access token is required');
  }

  if (!artist || !songTitle) {
    throw new Error('Artist and song title are required');
  }

  try {
    // Step 1: Search for the song on Genius
    const searchResults = await searchSong(artist, songTitle, accessToken, albumName);

    if (!searchResults || searchResults.length === 0) {
      throw new Error(`Song "${songTitle}" by ${artist} not found on Genius`);
    }

    // Get the first (best match) result
    const song = searchResults[0];

    // Step 2: Fetch the lyrics page HTML
    const htmlContent = await fetchPageHTML(song.url);

    // Step 3: Extract lyrics from the HTML
    const extracted = extractLyricsFromHTML(htmlContent);

    // Step 4: Clean the HTML content to plain text
    const cleanedLyrics = cleanLyricsHTML(extracted.rawHTML);

    // Return based on returnSongInfo option
    if (returnSongInfo) {
      return {
        lyrics: cleanedLyrics,
        songInfo: {
          id: song.id,
          title: song.title,
          artist: song.primary_artist.name,
          url: song.url,
          thumbnailUrl: song.song_art_image_thumbnail_url,
          imageUrl: song.song_art_image_url,
          releaseDate: song.release_date_for_display
        },
        containerCount: extracted.containerCount
      };
    }

    return cleanedLyrics;

  } catch (error) {
    // Re-throw with more context if it's not already our error
    if (error.message.includes('not found')) {
      throw error;
    }
    throw new Error(`Failed to fetch lyrics: ${error.message}`);
  }
}

export {
  fetchLyrics
};
