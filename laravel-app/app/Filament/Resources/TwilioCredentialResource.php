<?php

namespace App\Filament\Resources;

use App\Filament\Resources\TwilioCredentialResource\Pages;
use App\Models\TwilioCredential;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class TwilioCredentialResource extends Resource
{
    protected static ?string $model = TwilioCredential::class;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?string $navigationLabel = 'Twilio Settings';

    protected static ?int $navigationSort = 5;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Twilio API Credentials')
                    ->description('Configure your Twilio API credentials')
                    ->schema([
                        Forms\Components\TextInput::make('account_sid')
                            ->label('Account SID')
                            ->required()
                            ->placeholder('ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
                            ->helperText("Your Twilio Account SID (starts with 'AC' followed by 32 characters)"),
                        Forms\Components\TextInput::make('auth_token')
                            ->label('Auth Token')
                            ->required()
                            ->password()
                            ->placeholder('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
                            ->helperText('Your Twilio Auth Token (32 alphanumeric characters)'),
                    ]),

                Forms\Components\Section::make('Twilio Lookup API v2 Data Packages')
                    ->description('Configure which data packages to fetch with each lookup')
                    ->schema([
                        Forms\Components\Toggle::make('enable_line_type_intelligence')
                            ->label('Line Type Intelligence')
                            ->helperText('Get detailed line type info (mobile, landline, VoIP, etc.) with carrier details. Worldwide coverage.')
                            ->default(true),
                        Forms\Components\Toggle::make('enable_caller_name')
                            ->label('Caller Name (CNAM)')
                            ->helperText('Get caller name and type information. US numbers only.')
                            ->default(true),
                        Forms\Components\Toggle::make('enable_sms_pumping_risk')
                            ->label('SMS Pumping Fraud Risk')
                            ->helperText('Detect fraud risk with real-time risk scores (0-100). Essential for fraud prevention.')
                            ->default(true),
                        Forms\Components\Toggle::make('enable_sim_swap')
                            ->label('SIM Swap Detection')
                            ->helperText('Detect recent SIM changes for security verification. Limited coverage - requires carrier approval.')
                            ->default(false),
                        Forms\Components\Toggle::make('enable_reassigned_number')
                            ->label('Reassigned Number Detection')
                            ->helperText('Check if number has been reassigned to a new user. US only - requires approval.')
                            ->default(false),
                    ])
                    ->columns(1),

                Forms\Components\Section::make('Real Phone Validation (RPV)')
                    ->description('Verify if phone numbers are connected or disconnected')
                    ->schema([
                        Forms\Components\Toggle::make('enable_real_phone_validation')
                            ->label('Enable Real Phone Validation')
                            ->helperText('Check if phone lines are connected/disconnected in real-time. $0.06 per lookup.')
                            ->default(true),
                        Forms\Components\TextInput::make('rpv_unique_name')
                            ->label('RPV Add-on Unique Name')
                            ->placeholder('real_phone_validation_rpv_turbo')
                            ->helperText('The unique name you gave the RPV add-on when installing it in Twilio Console.'),
                    ]),

                Forms\Components\Section::make('IceHook Scout (Porting Data)')
                    ->description('Check if phone numbers have been ported')
                    ->schema([
                        Forms\Components\Toggle::make('enable_icehook_scout')
                            ->label('Enable IceHook Scout')
                            ->helperText('Check if numbers have been ported to a different carrier. Returns ported status, LRN, and operating company info.')
                            ->default(false),
                    ]),

                Forms\Components\Section::make('Business Intelligence Enrichment')
                    ->description('Enrich business contacts with company data')
                    ->schema([
                        Forms\Components\Toggle::make('enable_business_enrichment')
                            ->label('Enable Business Enrichment')
                            ->helperText('Automatically enrich contacts identified as businesses with company intelligence data'),
                        Forms\Components\Toggle::make('auto_enrich_businesses')
                            ->label('Auto-Enrich After Lookup')
                            ->helperText('Automatically queue business enrichment after successful Twilio lookup'),
                        Forms\Components\TextInput::make('enrichment_confidence_threshold')
                            ->label('Confidence Threshold (0-100)')
                            ->numeric()
                            ->minValue(0)
                            ->maxValue(100)
                            ->default(70)
                            ->helperText('Only save business data with confidence score above this threshold'),
                        Forms\Components\TextInput::make('clearbit_api_key')
                            ->label('Clearbit API Key')
                            ->password()
                            ->placeholder('sk_...')
                            ->helperText('Premium business intelligence (recommended). Get your key at https://clearbit.com'),
                        Forms\Components\TextInput::make('numverify_api_key')
                            ->label('NumVerify API Key')
                            ->password()
                            ->helperText('Basic phone intelligence with business detection. Get free key at https://numverify.com'),
                    ]),

                Forms\Components\Section::make('Email Enrichment & Verification')
                    ->description('Find and verify email addresses for contacts')
                    ->schema([
                        Forms\Components\Toggle::make('enable_email_enrichment')
                            ->label('Enable Email Enrichment')
                            ->helperText('Automatically find and verify email addresses for contacts after business enrichment'),
                        Forms\Components\TextInput::make('hunter_api_key')
                            ->label('Hunter.io API Key')
                            ->password()
                            ->helperText('Email finding and verification service. Get your key at https://hunter.io'),
                        Forms\Components\TextInput::make('zerobounce_api_key')
                            ->label('ZeroBounce API Key')
                            ->password()
                            ->helperText('Email verification service. Get your key at https://www.zerobounce.net'),
                    ]),

                Forms\Components\Section::make('Duplicate Detection & Merging')
                    ->description('Identify and merge duplicate contacts')
                    ->schema([
                        Forms\Components\Toggle::make('enable_duplicate_detection')
                            ->label('Enable Duplicate Detection')
                            ->helperText('Automatically check for duplicate contacts after enrichment'),
                        Forms\Components\TextInput::make('duplicate_confidence_threshold')
                            ->label('Confidence Threshold (0-100)')
                            ->numeric()
                            ->minValue(0)
                            ->maxValue(100)
                            ->default(75)
                            ->helperText('Show duplicates with confidence score above this threshold (recommended: 70-80)'),
                        Forms\Components\Toggle::make('auto_merge_duplicates')
                            ->label('Auto-Merge High Confidence Duplicates')
                            ->helperText('Automatically merge contacts with 95%+ confidence match (use with caution)')
                            ->default(false),
                    ]),

                Forms\Components\Section::make('AI Assistant (GPT Integration)')
                    ->description('Enable AI-powered features')
                    ->schema([
                        Forms\Components\Toggle::make('enable_ai_features')
                            ->label('Enable AI Features')
                            ->helperText('Unlock AI assistant, natural language search, and intelligent recommendations'),
                        Forms\Components\TextInput::make('openai_api_key')
                            ->label('OpenAI API Key')
                            ->password()
                            ->placeholder('sk-...')
                            ->helperText('Get your API key at https://platform.openai.com/api-keys'),
                        Forms\Components\Select::make('ai_model')
                            ->label('AI Model')
                            ->options([
                                'gpt-4o' => 'GPT-4o (Recommended - Fast & Smart)',
                                'gpt-4o-mini' => 'GPT-4o-mini (Budget-Friendly)',
                                'gpt-4-turbo' => 'GPT-4 Turbo (Most Capable)',
                                'gpt-3.5-turbo' => 'GPT-3.5 Turbo (Fastest)',
                            ])
                            ->default('gpt-4o-mini')
                            ->helperText('Choose the AI model for intelligence features (gpt-4o-mini recommended for sales use)'),
                        Forms\Components\TextInput::make('ai_max_tokens')
                            ->label('Max Response Tokens')
                            ->numeric()
                            ->minValue(100)
                            ->maxValue(4000)
                            ->default(1000)
                            ->helperText('Maximum tokens for AI responses (500-2000 recommended)'),
                    ]),

                Forms\Components\Section::make('OpenRouter (Multi-Model AI)')
                    ->description('Access 100+ AI models through one API')
                    ->schema([
                        Forms\Components\Toggle::make('enable_openrouter')
                            ->label('Enable OpenRouter')
                            ->helperText('Use OpenRouter as an alternative AI provider (overrides OpenAI when selected)'),
                        Forms\Components\TextInput::make('openrouter_api_key')
                            ->label('OpenRouter API Key')
                            ->password()
                            ->placeholder('sk-or-...')
                            ->helperText('Get your API key at https://openrouter.ai/keys'),
                        Forms\Components\TextInput::make('openrouter_model')
                            ->label('OpenRouter Model')
                            ->placeholder('anthropic/claude-3.5-sonnet')
                            ->helperText('Enter any model ID from openrouter.ai/models'),
                        Forms\Components\Select::make('preferred_llm_provider')
                            ->label('Preferred AI Provider')
                            ->options([
                                'openai' => 'OpenAI (Direct)',
                                'openrouter' => 'OpenRouter (Multi-Model)',
                                'anthropic' => 'Anthropic (Direct)',
                                'google' => 'Google AI (Direct)',
                            ])
                            ->default('openai')
                            ->helperText('Which AI provider to use by default for AI features'),
                    ]),

                Forms\Components\Section::make('Business Directory / Zipcode Lookup')
                    ->description('Search for businesses by zipcode')
                    ->schema([
                        Forms\Components\Toggle::make('enable_zipcode_lookup')
                            ->label('Enable Zipcode Business Lookup')
                            ->helperText('Allow searching and importing businesses by zipcode from business directories'),
                        Forms\Components\TextInput::make('results_per_zipcode')
                            ->label('Results Per Zipcode')
                            ->numeric()
                            ->minValue(1)
                            ->maxValue(300)
                            ->default(20)
                            ->helperText('Max businesses per zipcode. Yelp max: 240, Google max: 60. Combined: up to 300.'),
                        Forms\Components\Toggle::make('auto_enrich_zipcode_results')
                            ->label('Auto-Enrich Imported Businesses')
                            ->helperText('Automatically run phone lookup and email enrichment on newly imported businesses')
                            ->default(true),
                        Forms\Components\TextInput::make('google_places_api_key')
                            ->label('Google Places API Key')
                            ->password()
                            ->placeholder('AIza...')
                            ->helperText('Recommended for comprehensive business data. Get your key at https://console.cloud.google.com/apis'),
                        Forms\Components\TextInput::make('yelp_api_key')
                            ->label('Yelp Fusion API Key')
                            ->password()
                            ->helperText('Alternative/fallback source. Get your key at https://www.yelp.com/developers'),
                    ]),

                Forms\Components\Section::make('Address Enrichment & Verizon Coverage')
                    ->description('Find consumer addresses and check Verizon home internet availability')
                    ->schema([
                        Forms\Components\Toggle::make('enable_address_enrichment')
                            ->label('Enable Address Enrichment (Consumers Only)')
                            ->helperText('Find residential addresses for consumer contacts from phone numbers'),
                        Forms\Components\Toggle::make('enable_verizon_coverage_check')
                            ->label('Enable Verizon Coverage Check')
                            ->helperText('Automatically check if consumer addresses qualify for Verizon 5G/LTE Home Internet'),
                        Forms\Components\Toggle::make('auto_check_verizon_coverage')
                            ->label('Auto-Check After Address Found')
                            ->helperText('Automatically run Verizon coverage check when a valid address is found')
                            ->default(true),
                        Forms\Components\TextInput::make('whitepages_api_key')
                            ->label('Whitepages Pro API Key')
                            ->password()
                            ->helperText('For consumer address lookup'),
                        Forms\Components\TextInput::make('truecaller_api_key')
                            ->label('TrueCaller API Key')
                            ->password()
                            ->helperText('Alternative address source'),
                        Forms\Components\TextInput::make('verizon_account_name')
                            ->label('Verizon Account Name')
                            ->placeholder('Your account name')
                            ->helperText('Your Verizon ThingSpace account name for FWA API access'),
                        Forms\Components\TextInput::make('verizon_api_key')
                            ->label('Verizon API Key')
                            ->password()
                            ->helperText('API key from Verizon ThingSpace developer portal'),
                        Forms\Components\TextInput::make('verizon_api_secret')
                            ->label('Verizon API Secret')
                            ->password()
                            ->helperText('API secret from Verizon ThingSpace developer portal'),
                    ]),

                Forms\Components\Section::make('Notes')
                    ->schema([
                        Forms\Components\Textarea::make('notes')
                            ->label('Configuration Notes')
                            ->rows(4)
                            ->helperText('Optional: Add notes about your Twilio configuration, rate limits, or special settings'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('account_sid')
                    ->label('Account SID')
                    ->formatStateUsing(fn (string $state): string =>
                        substr($state, 0, 6) . '***' . substr($state, -4)
                    ),
                Tables\Columns\IconColumn::make('auth_token')
                    ->label('Auth Token')
                    ->boolean()
                    ->getStateUsing(fn ($record): bool => !empty($record->auth_token)),
                Tables\Columns\TextColumn::make('updated_at')
                    ->label('Last Updated')
                    ->dateTime('M d, Y H:i')
                    ->sortable(),
            ])
            ->filters([
                //
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                //
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListTwilioCredentials::route('/'),
            'create' => Pages\CreateTwilioCredential::route('/create'),
            'view' => Pages\ViewTwilioCredential::route('/{record}'),
            'edit' => Pages\EditTwilioCredential::route('/{record}/edit'),
        ];
    }
}
