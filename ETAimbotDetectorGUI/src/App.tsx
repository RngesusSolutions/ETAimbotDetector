import { useState } from 'react'
import { Shield, FileUp, AlertTriangle, Check, Loader2, Target, User, BarChart } from 'lucide-react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { analyzeDemo, AnalysisResult as ApiAnalysisResult } from './lib/api'

function App() {
  const [file, setFile] = useState<File | null>(null)
  const [analyzing, setAnalyzing] = useState(false)
  const [results, setResults] = useState<ApiAnalysisResult | null>(null)
  const [error, setError] = useState<string | null>(null)

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0]
    if (selectedFile) {
      if (selectedFile.name.endsWith('.dm_84')) {
        setFile(selectedFile)
        setError(null)
      } else {
        setFile(null)
        setError('Please select a valid .dm_84 file')
      }
    }
  }

  const handleAnalyze = async () => {
    if (!file) return
    
    setAnalyzing(true)
    setResults(null)
    
    try {
      // Call the API to analyze the demo file
      const result = await analyzeDemo(file)
      setResults(result)
    } catch (err) {
      setError('Failed to analyze demo file. Please try again.')
      console.error(err)
    } finally {
      setAnalyzing(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800 flex flex-col">
      {/* Header */}
      <header className="bg-white dark:bg-gray-950 shadow-sm backdrop-blur-md bg-opacity-80 dark:bg-opacity-80 sticky top-0 z-10">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Shield className="h-8 w-8 text-blue-500" />
            <h1 className="text-xl font-semibold text-gray-900 dark:text-white">ETAimbotDetector</h1>
          </div>
          <div className="flex items-center space-x-4">
            <a 
              href="https://github.com/RngesusSolutions/ETAimbotDetector" 
              target="_blank" 
              rel="noopener noreferrer"
              className="text-sm text-gray-600 dark:text-gray-400 hover:text-blue-500 dark:hover:text-blue-400 transition-colors"
            >
              GitHub
            </a>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto">
          {/* File Selection Card */}
          <Card className="mb-8 border-0 shadow-lg bg-white dark:bg-gray-950 overflow-hidden">
            <CardHeader className="bg-gradient-to-r from-blue-500 to-indigo-600 text-white">
              <CardTitle className="text-2xl font-light">Analyze Demo File</CardTitle>
              <CardDescription className="text-blue-100">
                Select an Enemy Territory demo file (.dm_84) to analyze for aimbot usage
              </CardDescription>
            </CardHeader>
            <CardContent className="pt-6">
              <div className="flex flex-col items-center justify-center p-8 border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-900">
                {analyzing ? (
                  <div className="flex flex-col items-center justify-center">
                    <Loader2 className="h-12 w-12 text-blue-500 animate-spin mb-4" />
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      Analyzing {file?.name}...
                    </p>
                    <div className="w-full max-w-xs mt-4">
                      <Progress className="h-1" value={undefined} />
                    </div>
                  </div>
                ) : (
                  <>
                    <FileUp className="h-12 w-12 text-gray-400 mb-4" />
                    <p className="text-sm text-gray-500 dark:text-gray-400 mb-4 text-center">
                      Drag and drop your .dm_84 file here, or click to browse
                    </p>
                    <input
                      type="file"
                      id="file-upload"
                      className="hidden"
                      accept=".dm_84"
                      onChange={handleFileChange}
                    />
                    <Button 
                      variant="outline" 
                      onClick={() => document.getElementById('file-upload')?.click()}
                      className="mb-2"
                    >
                      Select File
                    </Button>
                    {file && (
                      <p className="text-sm font-medium text-green-600 dark:text-green-400 mt-2">
                        {file.name} selected
                      </p>
                    )}
                    {error && (
                      <p className="text-sm font-medium text-red-600 dark:text-red-400 mt-2">
                        {error}
                      </p>
                    )}
                  </>
                )}
              </div>
            </CardContent>
            <CardFooter className="flex justify-end bg-gray-50 dark:bg-gray-900">
              <Button 
                onClick={handleAnalyze} 
                disabled={!file || analyzing}
                className="bg-blue-500 hover:bg-blue-600 text-white"
              >
                {analyzing ? 'Analyzing...' : 'Analyze Demo'}
              </Button>
            </CardFooter>
          </Card>

          {/* Results Card */}
          {results && (
            <Card className="border-0 shadow-lg bg-white dark:bg-gray-950 overflow-hidden">
              <CardHeader className="bg-gradient-to-r from-blue-500 to-indigo-600 text-white">
                <CardTitle className="text-2xl font-light">Analysis Results</CardTitle>
                <CardDescription className="text-blue-100">
                  Detection results for {file?.name}
                </CardDescription>
              </CardHeader>
              
              <Tabs defaultValue="summary" className="w-full">
                <div className="px-6 pt-6">
                  <TabsList className="grid w-full grid-cols-3">
                    <TabsTrigger value="summary" className="flex items-center gap-2">
                      <BarChart className="h-4 w-4" />
                      Summary
                    </TabsTrigger>
                    <TabsTrigger value="players" className="flex items-center gap-2">
                      <User className="h-4 w-4" />
                      Players
                    </TabsTrigger>
                    <TabsTrigger value="details" className="flex items-center gap-2">
                      <Target className="h-4 w-4" />
                      Details
                    </TabsTrigger>
                  </TabsList>
                </div>
                
                <TabsContent value="summary" className="p-6">
                  <div className="space-y-6">
                    {/* Overall Confidence */}
                    <div>
                      <div className="flex justify-between mb-2">
                        <h3 className="text-lg font-medium">Aimbot Detection Confidence</h3>
                        <span className="font-semibold">{results.confidence.toFixed(1)}%</span>
                      </div>
                      <Progress 
                        value={results.confidence} 
                        className="h-2"
                      />
                      
                      <Alert className={`mt-4 ${
                        results.confidence > 70 
                          ? 'border-red-500 dark:border-red-400' 
                          : results.confidence > 40 
                            ? 'border-yellow-500 dark:border-yellow-400'
                            : 'border-green-500 dark:border-green-400'
                      }`}>
                        <AlertTriangle className={`h-4 w-4 ${
                          results.confidence > 70 
                            ? 'text-red-500 dark:text-red-400' 
                            : results.confidence > 40 
                              ? 'text-yellow-500 dark:text-yellow-400'
                              : 'text-green-500 dark:text-green-400'
                        }`} />
                        <AlertTitle>
                          {results.confidence > 70 
                            ? 'High probability of aimbot detected' 
                            : results.confidence > 40 
                              ? 'Moderate probability of aimbot detected'
                              : 'Low probability of aimbot detected'
                          }
                        </AlertTitle>
                        <AlertDescription>
                          {results.confidence > 70 
                            ? 'The analysis indicates a high likelihood of aimbot usage in this demo.' 
                            : results.confidence > 40 
                              ? 'The analysis indicates some suspicious behavior that may be aimbot usage.'
                              : 'The analysis indicates minimal suspicious behavior in this demo.'
                          }
                        </AlertDescription>
                      </Alert>
                    </div>

                    <div className="rounded-lg bg-gray-50 dark:bg-gray-900 p-4">
                      <h3 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">Quick Summary</h3>
                      <p className="text-sm">
                        {results.suspectedPlayers.length > 0 
                          ? `Found ${results.suspectedPlayers.length} suspicious player${results.suspectedPlayers.length > 1 ? 's' : ''}.` 
                          : 'No suspicious players detected in this demo.'}
                        {results.suspectedPlayers.length > 0 && results.suspectedPlayers[0].probability > 70 && 
                          ` ${results.suspectedPlayers[0].name} has the highest probability of using an aimbot.`}
                      </p>
                    </div>
                  </div>
                </TabsContent>
                
                <TabsContent value="players" className="p-6">
                  <div className="space-y-4">
                    <h3 className="text-lg font-medium mb-4">Suspected Players</h3>
                    
                    {results.suspectedPlayers.length > 0 ? (
                      <div className="space-y-4">
                        {results.suspectedPlayers.map((player, index) => (
                          <div key={index} className="flex items-center justify-between p-4 rounded-lg bg-gray-50 dark:bg-gray-900">
                            <div className="flex items-center">
                              <div className={`w-2 h-10 rounded-full mr-4 ${
                                player.probability > 70 
                                  ? 'bg-red-500' 
                                  : player.probability > 40 
                                    ? 'bg-yellow-500' 
                                    : 'bg-green-500'
                              }`}></div>
                              <div>
                                <h4 className="font-medium">{player.name}</h4>
                                <p className="text-sm text-gray-500 dark:text-gray-400">
                                  {player.probability > 70 
                                    ? 'High probability' 
                                    : player.probability > 40 
                                      ? 'Moderate probability'
                                      : 'Low probability'
                                  }
                                </p>
                              </div>
                            </div>
                            <div className="text-xl font-bold">{player.probability.toFixed(1)}%</div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="flex items-center justify-center p-8 rounded-lg bg-gray-50 dark:bg-gray-900">
                        <Check className="h-6 w-6 text-green-500 mr-2" />
                        <p className="text-green-600 dark:text-green-400 font-medium">No suspicious players detected</p>
                      </div>
                    )}
                  </div>
                </TabsContent>
                
                <TabsContent value="details" className="p-6">
                  <div className="space-y-4">
                    <h3 className="text-lg font-medium mb-4">Detection Details</h3>
                    
                    <div className="rounded-lg bg-gray-50 dark:bg-gray-900 p-4">
                      <h4 className="font-medium mb-2">Analysis Information</h4>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div className="text-gray-500 dark:text-gray-400">File Name:</div>
                        <div>{file?.name}</div>
                        <div className="text-gray-500 dark:text-gray-400">File Size:</div>
                        <div>{(file?.size || 0) / 1024} KB</div>
                        <div className="text-gray-500 dark:text-gray-400">Analysis Date:</div>
                        <div>{new Date().toLocaleString()}</div>
                        <div className="text-gray-500 dark:text-gray-400">Detection Rules:</div>
                        <div>Velocity Prediction, Ping Prediction, Aim Lock, Smoothness</div>
                      </div>
                    </div>
                    
                    <div className="rounded-lg bg-gray-50 dark:bg-gray-900 p-4">
                      <h4 className="font-medium mb-2">Detection Methodology</h4>
                      <p className="text-sm text-gray-700 dark:text-gray-300">
                        ETAimbotDetector analyzes player aim patterns, target acquisition speed, 
                        and movement prediction to identify potential aimbot usage. The analysis 
                        includes checks for velocity prediction, ping compensation, and unnatural 
                        aim smoothness typical of aimbots like CCHookReloaded.
                      </p>
                    </div>
                  </div>
                </TabsContent>
              </Tabs>
            </Card>
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-white dark:bg-gray-950 border-t border-gray-200 dark:border-gray-800 py-6">
        <div className="container mx-auto px-4 text-center text-gray-500 dark:text-gray-400 text-sm">
          <div className="flex flex-col md:flex-row justify-center items-center gap-2 md:gap-6">
            <span>ETAimbotDetector GUI &copy; {new Date().getFullYear()}</span>
            <a href="https://github.com/RngesusSolutions/ETAimbotDetector" className="text-blue-500 hover:text-blue-600" target="_blank" rel="noopener noreferrer">
              GitHub Repository
            </a>
            <a href="https://github.com/RngesusSolutions/ETAimbotDetector/releases" className="text-blue-500 hover:text-blue-600" target="_blank" rel="noopener noreferrer">
              Download CLI Version
            </a>
          </div>
        </div>
      </footer>
    </div>
  )
}

export default App
