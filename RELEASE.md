A filesystem where unused files slowly "freeze" over time. Frozen files take longer to access, and extremely frozen files become read-only until "thawed."

## What is FrostFS?

FrostFS is an intelligent filesystem that automatically manages file accessibility based on usage patterns. Just like ice forming on a cold window, files that aren't used gradually accumulate "frost" - becoming slower to access and eventually read-only until explicitly thawed.

# See It In Action

Watch the demo video to see a quick overview of FrostFS's basic(cli, tui and the web interface) features—without having to install anything first.

<p align="center">
  <a href="https://hc-cdn.hel1.your-objectstorage.com/s/v3/e7cab4d4cb10d4156003ff26f27171df07641e42_frostfs-demo.mp4">
    <img src="https://dummyimage.com/800x450/000/fff&text=▶+Watch+FrostFS+Demo" alt="Watch the FrostFS Demo Video" width="600"/>
  </a>
</p>

### The Freezing Process:
- **Active** → **Chilled** → **Frozen** → **Deep Frozen** → **Glacier Storage**

## Features

### Core Freezing System
- **Automatic State Transitions**: Files automatically progress through freezing states based on access time
- **Configurable Timing**: Set your own chill/freeze/deep-freeze time thresholds
- **Access Delays**: Frozen files incur access delays simulating "thawing time"
- **Read-Only Protection**: Deep frozen files become read-only until thawed

### Advanced Freezing Features

#### Ice Crystals
Files accumulate fragmentation over time when frozen, simulating ice crystal formation:
- Fragmentation increases access delays
- Defragmentation process to restore performance
- Visual fragmentation percentage tracking

#### Frost Patterns  
Visual representation of file states with emoji patterns:
- `💧` Active - Recently accessed files
- `❄️` Chilled - Some delay in access  
- `🧊` Frozen - Significant access delay
- `🏔️` Deep Frozen - Read-only, requires thawing

#### Seasonal Thawing
Automatic batch thawing cycles based on seasons:
- **Spring**: Aggressive thawing (80% of frozen files)
- **Summer**: Moderate thawing (50%)
- **Autumn**: Light thawing (20%)
- **Winter**: No thawing - preservation mode

#### Freezing Algorithms
Multiple intelligent freezing strategies:
- **Standard**: Time-based freezing only
- **Intelligent**: Considers access frequency patterns
- **Predictive**: Predicts future access based on historical patterns

#### Antifreeze
Some files naturally resist freezing:
- Temporary files, logs, caches resist freezing
- File extensions and patterns affect antifreeze strength
- Configurable antifreeze properties

#### Glacier Storage
Deep archival system with cost-based recovery:
- Automatic archiving of deeply frozen files
- Compression for storage efficiency
- Recovery cost calculation
- Manual restore operations

#### Thermal Imaging
Heat maps of file activity:
- Visual representation of "hot" and "cold" files
- Access frequency and recency scoring
- Color-coded activity levels

#### Freeze Propagation
Directory-level freezing operations:
- Apply freezing policies to entire directories
- Inherited state management
- Batch operations on directory trees

## Commandline Interface 

```bash 
# Initialize a FrostFS directory
frostfs init ./my_frost_storage

# Write a file
frostfs write hello.txt "Hello World" -f ./my_frost_storage

# Read a file (with auto-thaw)
frostfs read hello.txt -f ./my_frost_storage --thaw

# List files with frost patterns
frostfs list -f ./my_frost_storage --details

# Show filesystem statistics
frostfs stats -f ./my_frost_storage

# Manually freeze a file
bin/frostfs freeze frozen_file.txt -f ./my_frost_storage

# Thaw frozen files
frostfs thaw frozen_file.txt -f ./my_frost_storage
```

## Terminal User Interface (TUI) 

### TUI Features  

- Dual-pane file browser with color-coded frost states
- Keyboard navigation (arrows, tab, enter)
- File operations (freeze, thaw, defragment)
- Batch operations menu
- Thermal map visualization
- Real-time file information

## Web Interface  

FrostFS also provides a browser-based GUI made using Ruby on Rails for easier management and visualization of the filesystem.:

https://github.com/arungeorgesaji/FrostFS-Web

### Web Features

- Dashboard & Analytics 
- File Management 
- Visualizations 
- System Operations 
- Monitoring 

P.S: Attached the gem file for the main frostfs library here so you can try out scripts in examples/ if you want. Use the following command to install the gem from the gem file:

```bash 
gem install frostfs-0.1.0.gem
```
