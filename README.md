# SkyBloom: Measure Your Night Sky!

SkyBloom is an app designed to help night sky enthusiasts with the problem of light pollution. Using the app, one can take a photo of their night sky, and using computer vision, the app will estimate the Bortle scale while also logging the reading with your location. The app also has other functionalities and features, listed below. 

Demo Video: 


## Motivation
Around 80% of Americans cannot see the Milky Way from where they live (Falchi et al., 2016). Artificial light at night (ALAN) is also shown to disrupt wildlife, waste energy, and affects human sleep. I built this app as part of my work with Night Bloom to allow people to collect light pollution data on their own sky. 

## Features
1. Sky Scanner: User captures a photo of their night sky, and the app estimates Bortle level. 
2. Light Pollution Map: Using the app, people interested in light pollution, or people looking to find dark locations for observation of the night sky can see an overlay of satellite light pollution data on Apple Maps, along with a feature that finds nearby dark spots.
3. Observation Log: Saves previous readings with the location, date, and notes. Observations are stored in Cloud Firestore which is tied to the user's account.
4. Learning: Contains an interactive Bortle scale reference, short articles on light pollution, and tips.

## Sky Analysis
The scanner runs on the device. It samples pixels across the image to measure overall sky glow, along with LED streetlight skyglow. Apple's Vision framework is used to estimate the number of stars visible, and the Bortle estimate combines all three of these, with star count (50%), brightness (35%), tint (15%). 

## Data Credits
Light pollution map tiles: David Lorenz's Light Pollution Atlas and lightpollutionmap.info, based on NASA/NOAA VIIRS satellite data.
Bortle scale: John E. Bortle, Sky & Telescope (2001).
