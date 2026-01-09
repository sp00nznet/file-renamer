#!/bin/bash

#===============================================================================
# Movie Renamer Script
# Identifies movies using The Movie Database (TMDB) API and renames files
# to format: "Movie Name (Year).ext"
#
# Requirements:
#   - curl
#   - jq
#   - TMDB API key (free at https://www.themoviedb.org/settings/api)
#
# Usage: ./movie_renamer.sh [directory]
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

#-------------------------------------------------------------------------------
# Function: show_usage
#-------------------------------------------------------------------------------
show_usage() {
    echo -e "${CYAN}Movie Renamer Script${NC}"
    echo ""
    echo "Usage: $0 [directory]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -k, --key      Set TMDB API key"
    echo "  -d, --dry-run  Show what would be renamed without making changes"
    echo ""
    echo "Environment Variables:"
    echo "  TMDB_API_KEY   Your TMDB API key (or use -k flag)"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/movies"
    echo "  TMDB_API_KEY=your_key $0 ."
    echo "  $0 -k your_key /path/to/movies"
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
# Function: process_file
# Main function to process a single movie file
#-------------------------------------------------------------------------------
process_file() {
    local filepath="$1"
    local dry_run="$2"
    
    local directory=$(dirname "$filepath")
    local filename=$(basename "$filepath")
    local extension="${filename##*.}"
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Processing:${NC} $filename"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Clean the filename for searching
    local cleaned=$(clean_filename "$filename")
    local search_name=$(echo "$cleaned" | cut -d'|' -f1)
    local detected_year=$(echo "$cleaned" | cut -d'|' -f2)
    
    echo -e "${BLUE}Detected movie name:${NC} $search_name"
    if [ -n "$detected_year" ]; then
        echo -e "${BLUE}Detected year:${NC} $detected_year"
    fi
    
    # Search TMDB
    echo -e "${BLUE}Searching TMDB...${NC}"
    local response=$(search_tmdb "$search_name" "$detected_year")
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to search TMDB${NC}"
        return 1
    fi
    
    # Display results
    if ! display_results "$response" "$filename"; then
        echo -e "${YELLOW}No matches found on TMDB${NC}"
        echo -e "Enter a custom search term (or 's' to skip): "
        read -r custom_search
        
        if [ "$custom_search" = "s" ] || [ -z "$custom_search" ]; then
            echo -e "${YELLOW}Skipping file${NC}"
            return 0
        fi
        
        response=$(search_tmdb "$custom_search" "")
        if ! display_results "$response" "$filename"; then
            echo -e "${RED}Still no matches found. Skipping.${NC}"
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
                return 0
            fi
            
            # Check if destination exists
            if [ -e "$new_filepath" ]; then
                echo -e "${RED}Warning: Destination file already exists!${NC}"
                echo -e "Overwrite? [y/N]: "
                read -r overwrite
                if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
                    echo -e "${YELLOW}Skipping to avoid overwrite${NC}"
                    return 0
                fi
            fi
            
            echo -e "Confirm rename? [Y/n]: "
            read -r confirm
            
            if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
                echo -e "${YELLOW}Rename cancelled${NC}"
                return 0
            fi
            
            if [ "$dry_run" = "true" ]; then
                echo -e "${CYAN}[DRY RUN] Would rename file${NC}"
            else
                mv "$filepath" "$new_filepath"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Successfully renamed!${NC}"
                else
                    echo -e "${RED}✗ Failed to rename file${NC}"
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
                process_file "$filepath" "$dry_run"
            fi
            ;;
        s|S|"")
            echo -e "${YELLOW}Skipping file${NC}"
            ;;
        *)
            echo -e "${RED}Invalid selection. Skipping.${NC}"
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

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Movie Renamer - TMDB Edition                     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Target directory:${NC} $TARGET_DIR"
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}Mode: DRY RUN (no changes will be made)${NC}"
fi
echo ""

# Find and process video files
file_count=0
processed_count=0

while IFS= read -r -d '' file; do
    ((file_count++))
    process_file "$file" "$DRY_RUN"
    ((processed_count++))
done < <(find "$TARGET_DIR" -maxdepth 1 -type f -regextype posix-extended -iregex ".*\.($VIDEO_EXTENSIONS)$" -print0 | sort -z)

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Done!${NC} Processed $processed_count of $file_count video files."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

if [ $file_count -eq 0 ]; then
    echo -e "${YELLOW}No video files found in $TARGET_DIR${NC}"
    echo "Supported extensions: ${VIDEO_EXTENSIONS//|/, }"
fi
