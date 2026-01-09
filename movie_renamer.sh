#!/bin/bash

#===============================================================================
# Media Renamer Script
# Identifies movies and TV shows using The Movie Database (TMDB) API and
# renames files to standardized formats:
#   - Movies: "Movie Name (Year).ext"
#   - TV Shows: "Show Name - S01E02 - Episode Title.ext"
#
# Requirements:
#   - curl
#   - jq
#   - TMDB API key (free at https://www.themoviedb.org/settings/api)
#
# Usage: ./movie_renamer.sh [options] [directory]
#        If no directory specified, uses current directory
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# TMDB API Configuration
# Get your free API key at: https://www.themoviedb.org/settings/api
TMDB_API_KEY="${TMDB_API_KEY:-}"

# Video file extensions to process
VIDEO_EXTENSIONS="mkv|mp4|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|ts|vob|divx|xvid"

# Logging configuration
LOG_FILE=""
LOG_ENABLED="false"

#-------------------------------------------------------------------------------
# Function: log_message
# Writes a timestamped message to the log file
#-------------------------------------------------------------------------------
log_message() {
    local level="$1"
    local message="$2"

    if [ "$LOG_ENABLED" = "true" ] && [ -n "$LOG_FILE" ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

#-------------------------------------------------------------------------------
# Function: log_info
#-------------------------------------------------------------------------------
log_info() {
    log_message "INFO" "$1"
}

#-------------------------------------------------------------------------------
# Function: log_warning
#-------------------------------------------------------------------------------
log_warning() {
    log_message "WARN" "$1"
}

#-------------------------------------------------------------------------------
# Function: log_error
#-------------------------------------------------------------------------------
log_error() {
    log_message "ERROR" "$1"
}

#-------------------------------------------------------------------------------
# Function: log_success
#-------------------------------------------------------------------------------
log_success() {
    log_message "SUCCESS" "$1"
}

#-------------------------------------------------------------------------------
# Function: init_logging
# Initializes the log file with a session header
#-------------------------------------------------------------------------------
init_logging() {
    if [ "$LOG_ENABLED" = "true" ] && [ -n "$LOG_FILE" ]; then
        # Create log directory if it doesn't exist
        local log_dir=$(dirname "$LOG_FILE")
        if [ ! -d "$log_dir" ] && [ "$log_dir" != "." ]; then
            mkdir -p "$log_dir"
        fi

        echo "" >> "$LOG_FILE"
        echo "================================================================================" >> "$LOG_FILE"
        echo "Media Renamer Session Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
        echo "Target Directory: $TARGET_DIR" >> "$LOG_FILE"
        echo "Dry Run: $DRY_RUN" >> "$LOG_FILE"
        echo "================================================================================" >> "$LOG_FILE"
    fi
}

#-------------------------------------------------------------------------------
# Function: detect_tv_show
# Detects if a filename is a TV show and extracts season/episode info
# Returns: "show_name|season|episode" or empty if not a TV show
#-------------------------------------------------------------------------------
detect_tv_show() {
    local filename="$1"

    # Remove extension
    local name="${filename%.*}"

    # Pattern 1: S01E02 format (most common)
    if [[ "$name" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
        local season="${BASH_REMATCH[1]}"
        local episode="${BASH_REMATCH[2]}"
        # Extract show name (everything before the pattern)
        local show_name=$(echo "$name" | sed -E 's/[._-]?[Ss][0-9]{1,2}[Ee][0-9]{1,2}.*//')
        show_name=$(echo "$show_name" | sed -E 's/[._-]+/ /g' | sed -E 's/^\s+|\s+$//g')
        echo "$show_name|$season|$episode"
        return 0
    fi

    # Pattern 2: 1x02 format
    if [[ "$name" =~ ([0-9]{1,2})x([0-9]{1,2}) ]]; then
        local season="${BASH_REMATCH[1]}"
        local episode="${BASH_REMATCH[2]}"
        local show_name=$(echo "$name" | sed -E 's/[._-]?[0-9]{1,2}x[0-9]{1,2}.*//')
        show_name=$(echo "$show_name" | sed -E 's/[._-]+/ /g' | sed -E 's/^\s+|\s+$//g')
        echo "$show_name|$season|$episode"
        return 0
    fi

    # Pattern 3: Season 1 Episode 2 format
    if [[ "$name" =~ [Ss]eason[._\ -]?([0-9]{1,2})[._\ -]?[Ee]pisode[._\ -]?([0-9]{1,2}) ]]; then
        local season="${BASH_REMATCH[1]}"
        local episode="${BASH_REMATCH[2]}"
        local show_name=$(echo "$name" | sed -Ei 's/[._-]?[Ss]eason.*//')
        show_name=$(echo "$show_name" | sed -E 's/[._-]+/ /g' | sed -E 's/^\s+|\s+$//g')
        echo "$show_name|$season|$episode"
        return 0
    fi

    # Not detected as TV show
    return 1
}

#-------------------------------------------------------------------------------
# Function: clean_show_name
# Cleans a TV show name for searching
#-------------------------------------------------------------------------------
clean_show_name() {
    local name="$1"

    # Replace common separators with spaces
    name=$(echo "$name" | sed -E 's/[._-]+/ /g')

    # Remove year in parentheses/brackets if present
    name=$(echo "$name" | sed -E 's/\([0-9]{4}\)//g' | sed -E 's/\[[0-9]{4}\]//g')

    # Remove common quality indicators
    name=$(echo "$name" | sed -E 's/\b(720p|1080p|2160p|4k|uhd|hdr|bluray|brrip|bdrip|dvdrip|webrip|web-dl|webdl|hdtv|xvid|divx|x264|x265|h264|h265|hevc|aac|ac3|dts|5\.1|7\.1|proper|repack)\b//gi')

    # Remove extra whitespace
    name=$(echo "$name" | sed -E 's/\s+/ /g' | sed -E 's/^\s+|\s+$//g')

    # Remove common group names
    name=$(echo "$name" | sed -E 's/\s+(yify|yts|rarbg|eztv|ettv|sparks|axxo|fgt|ctrlhd|ntb|mtb|publichd|lol|dimension|fleet|killers|fov|bamboozle).*$//gi')

    # Final cleanup
    name=$(echo "$name" | sed -E 's/\s+/ /g' | sed -E 's/^\s+|\s+$//g')

    echo "$name"
}

#-------------------------------------------------------------------------------
# Function: show_usage
#-------------------------------------------------------------------------------
show_usage() {
    echo -e "${CYAN}Media Renamer Script${NC}"
    echo ""
    echo "Renames movies and TV shows using TMDB metadata."
    echo ""
    echo "Usage: $0 [options] [directory]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -k, --key KEY    Set TMDB API key"
    echo "  -d, --dry-run    Show what would be renamed without making changes"
    echo "  -l, --log FILE   Enable logging to specified file"
    echo ""
    echo "Environment Variables:"
    echo "  TMDB_API_KEY     Your TMDB API key (or use -k flag)"
    echo ""
    echo "Output Formats:"
    echo "  Movies:    Movie Name (Year).ext"
    echo "  TV Shows:  Show Name - S01E02 - Episode Title.ext"
    echo ""
    echo "Supported Patterns:"
    echo "  TV Shows:  S01E02, 1x02, Season.1.Episode.2"
    echo "  Movies:    Any video file without TV patterns"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/media"
    echo "  $0 -k your_key -l rename.log /path/to/media"
    echo "  $0 -d /path/to/media   # Preview only"
    echo ""
    echo "Get a free TMDB API key at: https://www.themoviedb.org/settings/api"
}

#-------------------------------------------------------------------------------
# Function: check_dependencies
#-------------------------------------------------------------------------------
check_dependencies() {
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing[*]}${NC}"
        echo "Install with: sudo apt install ${missing[*]}"
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Function: clean_filename
# Extracts a searchable movie name from filename
#-------------------------------------------------------------------------------
clean_filename() {
    local filename="$1"
    
    # Remove file extension
    local name="${filename%.*}"
    
    # Replace common separators with spaces
    name=$(echo "$name" | sed -E 's/[._-]+/ /g')
    
    # Remove common release group tags and quality indicators
    name=$(echo "$name" | sed -E 's/\b(720p|1080p|2160p|4k|uhd|hdr|bluray|brrip|bdrip|dvdrip|webrip|web-dl|webdl|hdtv|xvid|divx|x264|x265|h264|h265|hevc|aac|ac3|dts|5\.1|7\.1|proper|repack|extended|unrated|directors cut|theatrical|remastered)\b//gi')
    
    # Remove year in brackets/parentheses temporarily (we'll search for it)
    local year=$(echo "$name" | grep -oE '\b(19|20)[0-9]{2}\b' | head -1)
    name=$(echo "$name" | sed -E 's/\b(19|20)[0-9]{2}\b//g')
    
    # Remove extra whitespace
    name=$(echo "$name" | sed -E 's/\s+/ /g' | sed -E 's/^\s+|\s+$//g')
    
    # Remove common group names at the end
    name=$(echo "$name" | sed -E 's/\s+(yify|yts|rarbg|eztv|ettv|sparks|axxo|fgt|ctrlhd|ntb|mtb|publichd).*$//gi')
    
    # Final cleanup
    name=$(echo "$name" | sed -E 's/\s+/ /g' | sed -E 's/^\s+|\s+$//g')
    
    # Return both name and detected year
    echo "$name|$year"
}

#-------------------------------------------------------------------------------
# Function: search_tmdb
# Searches TMDB for a movie and returns results
#-------------------------------------------------------------------------------
search_tmdb() {
    local query="$1"
    local year="$2"
    
    # URL encode the query
    local encoded_query=$(echo "$query" | sed 's/ /%20/g' | sed "s/'/%27/g")
    
    local url="https://api.themoviedb.org/3/search/movie?api_key=${TMDB_API_KEY}&query=${encoded_query}&language=en-US&page=1&include_adult=false"
    
    # Add year if available for better matching
    if [ -n "$year" ]; then
        url="${url}&year=${year}"
    fi
    
    local response=$(curl -s "$url")
    
    # Check for API errors
    if echo "$response" | jq -e '.status_code' &> /dev/null; then
        local error_msg=$(echo "$response" | jq -r '.status_message')
        echo -e "${RED}API Error: $error_msg${NC}" >&2
        return 1
    fi
    
    echo "$response"
}

#-------------------------------------------------------------------------------
# Function: search_tmdb_tv
# Searches TMDB for a TV show and returns results
#-------------------------------------------------------------------------------
search_tmdb_tv() {
    local query="$1"

    # URL encode the query
    local encoded_query=$(echo "$query" | sed 's/ /%20/g' | sed "s/'/%27/g")

    local url="https://api.themoviedb.org/3/search/tv?api_key=${TMDB_API_KEY}&query=${encoded_query}&language=en-US&page=1&include_adult=false"

    log_info "Searching TMDB TV: $query"

    local response=$(curl -s "$url")

    # Check for API errors
    if echo "$response" | jq -e '.status_code' &> /dev/null; then
        local error_msg=$(echo "$response" | jq -r '.status_message')
        echo -e "${RED}API Error: $error_msg${NC}" >&2
        log_error "TMDB API Error: $error_msg"
        return 1
    fi

    echo "$response"
}

#-------------------------------------------------------------------------------
# Function: get_episode_details
# Gets episode title from TMDB for a specific season/episode
#-------------------------------------------------------------------------------
get_episode_details() {
    local show_id="$1"
    local season="$2"
    local episode="$3"

    # Remove leading zeros for API call
    season=$((10#$season))
    episode=$((10#$episode))

    local url="https://api.themoviedb.org/3/tv/${show_id}/season/${season}/episode/${episode}?api_key=${TMDB_API_KEY}&language=en-US"

    log_info "Fetching episode details: Show ID $show_id, S${season}E${episode}"

    local response=$(curl -s "$url")

    # Check for API errors
    if echo "$response" | jq -e '.status_code' &> /dev/null; then
        local error_msg=$(echo "$response" | jq -r '.status_message')
        log_warning "Episode details not found: $error_msg"
        echo ""
        return 1
    fi

    local episode_name=$(echo "$response" | jq -r '.name // empty')
    echo "$episode_name"
}

#-------------------------------------------------------------------------------
# Function: display_tv_results
# Shows TV show search results and prompts for selection
#-------------------------------------------------------------------------------
display_tv_results() {
    local response="$1"

    local total_results=$(echo "$response" | jq '.total_results')

    if [ "$total_results" -eq 0 ]; then
        return 1
    fi

    echo ""
    echo -e "${CYAN}Found TV shows:${NC}"
    echo "----------------------------------------"

    # Display up to 5 results
    local count=$(echo "$response" | jq '[.results[:5] | length] | add')

    for i in $(seq 0 $((count - 1))); do
        local name=$(echo "$response" | jq -r ".results[$i].name")
        local first_air_date=$(echo "$response" | jq -r ".results[$i].first_air_date")
        local year=$(echo "$first_air_date" | cut -d'-' -f1)
        local overview=$(echo "$response" | jq -r ".results[$i].overview" | head -c 100)
        local vote=$(echo "$response" | jq -r ".results[$i].vote_average")

        echo -e "${YELLOW}[$((i + 1))]${NC} $name ($year)"
        echo -e "    Rating: $vote/10"
        if [ -n "$overview" ] && [ "$overview" != "null" ]; then
            echo -e "    ${BLUE}${overview}...${NC}"
        fi
        echo ""
    done

    return 0
}

#-------------------------------------------------------------------------------
# Function: get_tv_filename
# Creates the new filename in "Show Name - S01E02 - Episode Title.ext" format
#-------------------------------------------------------------------------------
get_tv_filename() {
    local show_name="$1"
    local season="$2"
    local episode="$3"
    local episode_title="$4"
    local extension="$5"

    # Sanitize show name for filename (remove invalid characters)
    local safe_show=$(echo "$show_name" | sed -E 's/[<>:"/\\|?*]//g')
    safe_show=$(echo "$safe_show" | sed 's/：/-/g')  # Full-width colon

    # Format season and episode with leading zeros
    local formatted_season=$(printf "%02d" $((10#$season)))
    local formatted_episode=$(printf "%02d" $((10#$episode)))

    if [ -n "$episode_title" ] && [ "$episode_title" != "null" ]; then
        # Sanitize episode title
        local safe_episode_title=$(echo "$episode_title" | sed -E 's/[<>:"/\\|?*]//g')
        safe_episode_title=$(echo "$safe_episode_title" | sed 's/：/-/g')
        echo "${safe_show} - S${formatted_season}E${formatted_episode} - ${safe_episode_title}.${extension}"
    else
        echo "${safe_show} - S${formatted_season}E${formatted_episode}.${extension}"
    fi
}

#-------------------------------------------------------------------------------
# Function: process_tv_file
# Processes a TV show file for renaming
#-------------------------------------------------------------------------------
process_tv_file() {
    local filepath="$1"
    local dry_run="$2"
    local show_name="$3"
    local season="$4"
    local episode="$5"

    local directory=$(dirname "$filepath")
    local filename=$(basename "$filepath")
    local extension="${filename##*.}"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Processing TV Show:${NC} $filename"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

    # Clean the show name
    local cleaned_show=$(clean_show_name "$show_name")

    echo -e "${BLUE}Detected show:${NC} $cleaned_show"
    echo -e "${BLUE}Season:${NC} $season  ${BLUE}Episode:${NC} $episode"

    log_info "Processing TV file: $filename"
    log_info "Detected: $cleaned_show S${season}E${episode}"

    # Search TMDB for the TV show
    echo -e "${BLUE}Searching TMDB...${NC}"
    local response=$(search_tmdb_tv "$cleaned_show")

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to search TMDB${NC}"
        log_error "Failed to search TMDB for: $cleaned_show"
        return 1
    fi

    # Display results
    if ! display_tv_results "$response"; then
        echo -e "${YELLOW}No matches found on TMDB${NC}"
        log_warning "No matches found for: $cleaned_show"
        echo -e "Enter a custom search term (or 's' to skip): "
        read -r custom_search

        if [ "$custom_search" = "s" ] || [ -z "$custom_search" ]; then
            echo -e "${YELLOW}Skipping file${NC}"
            log_info "Skipped: $filename (user choice)"
            return 0
        fi

        response=$(search_tmdb_tv "$custom_search")
        if ! display_tv_results "$response"; then
            echo -e "${RED}Still no matches found. Skipping.${NC}"
            log_warning "No matches found after custom search: $custom_search"
            return 0
        fi
    fi

    # Prompt for selection
    local count=$(echo "$response" | jq '[.results[:5] | length] | add')
    echo -e "Select match [1-$count], 'n' for new search, 's' to skip: "
    read -r selection

    case "$selection" in
        [1-5])
            local idx=$((selection - 1))
            local show_title=$(echo "$response" | jq -r ".results[$idx].name")
            local show_id=$(echo "$response" | jq -r ".results[$idx].id")

            log_info "User selected: $show_title (ID: $show_id)"

            # Get episode title
            echo -e "${BLUE}Fetching episode details...${NC}"
            local episode_title=$(get_episode_details "$show_id" "$season" "$episode")

            local new_filename=$(get_tv_filename "$show_title" "$season" "$episode" "$episode_title" "$extension")
            local new_filepath="${directory}/${new_filename}"

            echo ""
            echo -e "${GREEN}Will rename:${NC}"
            echo -e "  From: ${YELLOW}$filename${NC}"
            echo -e "  To:   ${GREEN}$new_filename${NC}"
            echo ""

            # Check if file already has correct name
            if [ "$filename" = "$new_filename" ]; then
                echo -e "${GREEN}File already has the correct name!${NC}"
                log_info "File already correctly named: $filename"
                return 0
            fi

            # Check if destination exists
            if [ -e "$new_filepath" ]; then
                echo -e "${RED}Warning: Destination file already exists!${NC}"
                echo -e "Overwrite? [y/N]: "
                read -r overwrite
                if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
                    echo -e "${YELLOW}Skipping to avoid overwrite${NC}"
                    log_warning "Skipped to avoid overwrite: $new_filename"
                    return 0
                fi
            fi

            echo -e "Confirm rename? [Y/n]: "
            read -r confirm

            if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
                echo -e "${YELLOW}Rename cancelled${NC}"
                log_info "Rename cancelled by user: $filename"
                return 0
            fi

            if [ "$dry_run" = "true" ]; then
                echo -e "${CYAN}[DRY RUN] Would rename file${NC}"
                log_info "[DRY RUN] Would rename: $filename -> $new_filename"
            else
                mv "$filepath" "$new_filepath"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Successfully renamed!${NC}"
                    log_success "Renamed: $filename -> $new_filename"
                else
                    echo -e "${RED}✗ Failed to rename file${NC}"
                    log_error "Failed to rename: $filename"
                    return 1
                fi
            fi
            ;;
        n|N)
            echo -e "Enter new search term: "
            read -r new_search
            if [ -n "$new_search" ]; then
                response=$(search_tmdb_tv "$new_search")
                display_tv_results "$response"
                process_tv_file "$filepath" "$dry_run" "$new_search" "$season" "$episode"
            fi
            ;;
        s|S|"")
            echo -e "${YELLOW}Skipping file${NC}"
            log_info "Skipped: $filename (user choice)"
            ;;
        *)
            echo -e "${RED}Invalid selection. Skipping.${NC}"
            log_warning "Invalid selection for: $filename"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Function: display_results
# Shows search results and prompts for selection
#-------------------------------------------------------------------------------
display_results() {
    local response="$1"
    local original_file="$2"
    
    local total_results=$(echo "$response" | jq '.total_results')
    
    if [ "$total_results" -eq 0 ]; then
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Found matches:${NC}"
    echo "----------------------------------------"
    
    # Display up to 5 results
    local count=$(echo "$response" | jq '[.results[:5] | length] | add')
    
    for i in $(seq 0 $((count - 1))); do
        local title=$(echo "$response" | jq -r ".results[$i].title")
        local release_date=$(echo "$response" | jq -r ".results[$i].release_date")
        local year=$(echo "$release_date" | cut -d'-' -f1)
        local overview=$(echo "$response" | jq -r ".results[$i].overview" | head -c 100)
        local vote=$(echo "$response" | jq -r ".results[$i].vote_average")
        
        echo -e "${YELLOW}[$((i + 1))]${NC} $title ($year)"
        echo -e "    Rating: $vote/10"
        if [ -n "$overview" ] && [ "$overview" != "null" ]; then
            echo -e "    ${BLUE}${overview}...${NC}"
        fi
        echo ""
    done
    
    return 0
}

#-------------------------------------------------------------------------------
# Function: get_new_filename
# Creates the new filename in "Movie Name (Year).ext" format
#-------------------------------------------------------------------------------
get_new_filename() {
    local title="$1"
    local year="$2"
    local extension="$3"
    
    # Sanitize title for filename (remove invalid characters)
    local safe_title=$(echo "$title" | sed -E 's/[<>:"/\\|?*]//g')
    
    # Replace colons with " -" for better readability (e.g., "Star Wars: A New Hope" -> "Star Wars - A New Hope")
    # Or keep colon-like format using dash
    safe_title=$(echo "$safe_title" | sed 's/：/-/g')  # Full-width colon
    
    echo "${safe_title} (${year}).${extension}"
}

#-------------------------------------------------------------------------------
# Function: process_movie_file
# Main function to process a single movie file
#-------------------------------------------------------------------------------
process_movie_file() {
    local filepath="$1"
    local dry_run="$2"

    local directory=$(dirname "$filepath")
    local filename=$(basename "$filepath")
    local extension="${filename##*.}"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Processing Movie:${NC} $filename"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

    # Clean the filename for searching
    local cleaned=$(clean_filename "$filename")
    local search_name=$(echo "$cleaned" | cut -d'|' -f1)
    local detected_year=$(echo "$cleaned" | cut -d'|' -f2)

    echo -e "${BLUE}Detected movie name:${NC} $search_name"
    if [ -n "$detected_year" ]; then
        echo -e "${BLUE}Detected year:${NC} $detected_year"
    fi

    log_info "Processing movie file: $filename"
    log_info "Detected movie: $search_name (Year: ${detected_year:-unknown})"

    # Search TMDB
    echo -e "${BLUE}Searching TMDB...${NC}"
    local response=$(search_tmdb "$search_name" "$detected_year")

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to search TMDB${NC}"
        log_error "Failed to search TMDB for: $search_name"
        return 1
    fi

    # Display results
    if ! display_results "$response" "$filename"; then
        echo -e "${YELLOW}No matches found on TMDB${NC}"
        log_warning "No matches found for: $search_name"
        echo -e "Enter a custom search term (or 's' to skip): "
        read -r custom_search

        if [ "$custom_search" = "s" ] || [ -z "$custom_search" ]; then
            echo -e "${YELLOW}Skipping file${NC}"
            log_info "Skipped: $filename (user choice)"
            return 0
        fi

        response=$(search_tmdb "$custom_search" "")
        if ! display_results "$response" "$filename"; then
            echo -e "${RED}Still no matches found. Skipping.${NC}"
            log_warning "No matches found after custom search: $custom_search"
            return 0
        fi
    fi

    # Prompt for selection
    local count=$(echo "$response" | jq '[.results[:5] | length] | add')
    echo -e "Select match [1-$count], 'n' for new search, 's' to skip: "
    read -r selection

    case "$selection" in
        [1-5])
            local idx=$((selection - 1))
            local title=$(echo "$response" | jq -r ".results[$idx].title")
            local release_date=$(echo "$response" | jq -r ".results[$idx].release_date")
            local year=$(echo "$release_date" | cut -d'-' -f1)

            log_info "User selected: $title ($year)"

            local new_filename=$(get_new_filename "$title" "$year" "$extension")
            local new_filepath="${directory}/${new_filename}"

            echo ""
            echo -e "${GREEN}Will rename:${NC}"
            echo -e "  From: ${YELLOW}$filename${NC}"
            echo -e "  To:   ${GREEN}$new_filename${NC}"
            echo ""

            # Check if file already has correct name
            if [ "$filename" = "$new_filename" ]; then
                echo -e "${GREEN}File already has the correct name!${NC}"
                log_info "File already correctly named: $filename"
                return 0
            fi

            # Check if destination exists
            if [ -e "$new_filepath" ]; then
                echo -e "${RED}Warning: Destination file already exists!${NC}"
                echo -e "Overwrite? [y/N]: "
                read -r overwrite
                if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
                    echo -e "${YELLOW}Skipping to avoid overwrite${NC}"
                    log_warning "Skipped to avoid overwrite: $new_filename"
                    return 0
                fi
            fi

            echo -e "Confirm rename? [Y/n]: "
            read -r confirm

            if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
                echo -e "${YELLOW}Rename cancelled${NC}"
                log_info "Rename cancelled by user: $filename"
                return 0
            fi

            if [ "$dry_run" = "true" ]; then
                echo -e "${CYAN}[DRY RUN] Would rename file${NC}"
                log_info "[DRY RUN] Would rename: $filename -> $new_filename"
            else
                mv "$filepath" "$new_filepath"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Successfully renamed!${NC}"
                    log_success "Renamed: $filename -> $new_filename"
                else
                    echo -e "${RED}✗ Failed to rename file${NC}"
                    log_error "Failed to rename: $filename"
                    return 1
                fi
            fi
            ;;
        n|N)
            echo -e "Enter new search term: "
            read -r new_search
            if [ -n "$new_search" ]; then
                response=$(search_tmdb "$new_search" "")
                display_results "$response" "$filename"
                process_movie_file "$filepath" "$dry_run"
            fi
            ;;
        s|S|"")
            echo -e "${YELLOW}Skipping file${NC}"
            log_info "Skipped: $filename (user choice)"
            ;;
        *)
            echo -e "${RED}Invalid selection. Skipping.${NC}"
            log_warning "Invalid selection for: $filename"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Main Script
#-------------------------------------------------------------------------------

# Parse arguments
DRY_RUN="false"
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -k|--key)
            TMDB_API_KEY="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            LOG_ENABLED="true"
            shift 2
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Check dependencies
check_dependencies

# Check for API key
if [ -z "$TMDB_API_KEY" ]; then
    echo -e "${RED}Error: TMDB API key is required${NC}"
    echo ""
    echo "Set your API key using one of these methods:"
    echo "  1. Environment variable: export TMDB_API_KEY=your_key"
    echo "  2. Command line flag: $0 -k your_key [directory]"
    echo ""
    echo "Get a free API key at: https://www.themoviedb.org/settings/api"
    exit 1
fi

# Set target directory
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="."
fi

# Verify directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory '$TARGET_DIR' does not exist${NC}"
    exit 1
fi

# Convert to absolute path
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

# Initialize logging
init_logging

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Media Renamer - TMDB Edition                     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Target directory:${NC} $TARGET_DIR"
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}Mode: DRY RUN (no changes will be made)${NC}"
fi
if [ "$LOG_ENABLED" = "true" ]; then
    echo -e "${BLUE}Logging to:${NC} $LOG_FILE"
fi
echo ""

# Find and process video files
file_count=0
movie_count=0
tv_count=0

while IFS= read -r -d '' file; do
    ((file_count++))
    filename=$(basename "$file")

    # Check if it's a TV show (has season/episode pattern)
    tv_info=$(detect_tv_show "$filename")
    if [ $? -eq 0 ] && [ -n "$tv_info" ]; then
        # It's a TV show
        show_name=$(echo "$tv_info" | cut -d'|' -f1)
        season=$(echo "$tv_info" | cut -d'|' -f2)
        episode=$(echo "$tv_info" | cut -d'|' -f3)
        process_tv_file "$file" "$DRY_RUN" "$show_name" "$season" "$episode"
        ((tv_count++))
    else
        # It's a movie
        process_movie_file "$file" "$DRY_RUN"
        ((movie_count++))
    fi
done < <(find "$TARGET_DIR" -maxdepth 1 -type f -regextype posix-extended -iregex ".*\.($VIDEO_EXTENSIONS)$" -print0 | sort -z)

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Done!${NC} Processed $file_count video files."
echo -e "  Movies: $movie_count  |  TV Episodes: $tv_count"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

log_info "Session complete: $file_count files processed ($movie_count movies, $tv_count TV episodes)"

if [ $file_count -eq 0 ]; then
    echo -e "${YELLOW}No video files found in $TARGET_DIR${NC}"
    echo "Supported extensions: ${VIDEO_EXTENSIONS//|/, }"
fi
